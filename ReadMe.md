# Superset Investigation of NY Powerball Lottery numbers
#### Author: Sacrebleu, 2024

#### Prerequisites

1. Terraform 1.7.x
2. git
3. awscli
4. kubectl

#### Tl;Dr How to run

###### Precursors

    $ export AWS_ACCESS_KEY_ID=<access key>
    $ export AWS_SECRET_ACCESS_KEY=<secret key>

###### Initial Infrastructure Build - VPC, IAM, EKS cluster, Athena workspace and Glue data catalog

    $ cd ./tf
    $ terraform init
    $ terraform plan -out plan.out 
    $ terraform apply -plan plan.out

###### Helm application provisioning

    $ cd ./helm
    $ terraform init
    $ terraform plan -out plan.out 
    $ terraform apply -plan plan.out

###### Post-terraform steps

1.  The EKS module creates a cluster KMS key but does not make it obvious as to how to append specific permissions to the key profile during provisioning.  I eventually removed the key creation from the eks module invocation, imported the existing resources from a prior run into terraform resources, and defined the kms key as `aws_kms_key.cluster_key` and its associated policy as  `aws_kms_key_policy.eks_cluster_policy`

so that I could guarantee the creation of the required KMS permissions for `module.eks.cluster_iam_role_arn` and `aws_iam_role.athena_access_role.arn`

2. Superset required a custom secret that was generated with `openssl rand 16 -base64`.  This would be more useful if it were generated automatically, but there would be a chance that it could be accidentally altered during a run; superset has a defined secret rotation process that this would then violate.  In production, I would make use of a Kubernetes External Secret linked to AWS SecretsManager for this.

3. A superset user was manaully  created alongside the admin user.  This user has read access to the generated data dashboard.  In a production system, users would be in LDAP or, preferably, a SAML-federation system like OKTA that would permit external definition of roles.  RBAC mapping could then be done between the external access control system and the internal superset roles.

4. superset datasets were created  manually via the superset ui.  Ideally these would be generated as part of the superset bootstrap process but I didn't feel discovery of this process was a useful use of time at this stage.

5. An Athena view (Detailed further below) was created manually in the AWS Athena console.

#### Superset Dataset Configuration

The initial data table is based on the csv file upload.  However, I created some derived fields which were then complex to visualise.  I took the decision to create a separate view for the combined winning ball numbers:

    CREATE OR REPLACE VIEW lottery_winning_numbers_merged AS
    select split_part(winning_numbers, ' ', 1) as num from lottery_numbers
    union all
    select split_part(winning_numbers, ' ', 2) as num from lottery_numbers
    union all
    select split_part(winning_numbers, ' ', 3) as num from lottery_numbers
    union all
    select split_part(winning_numbers, ' ', 4) as num from lottery_numbers
    union all
    select split_part(winning_numbers, ' ', 5) as num from lottery_numbers

this leverages sql to provide a unified list of numbers which are then more amenable to counting, placing into histograms etcetera.

---

## Design decisions

#### 1. Wide-ranging roles were given to the project provisioning user

In a normal environment, I would have either used an IAM boundary policy or spent  more time locking down the roles for the terraform user, but I am not familiar enough with Glue and Athena to guess what roles will be needed and my time was limited.  Therefore I have in general used the AWS provisioned roles for service users where I could, and inline IAM policies elsewhere.  All are allocated via a user-group for ease of management

#### 2. EKS as a platform

I chose EKS because I have good experience with it in my day to day.  In the guise of what is being done here it is easy to reason about, there is limited use of more complex Kubernetes concepts, most of this project is Deployments, Ingresses etcetera.  EKS gives me a fast, responsive platform with rich tooling that I can use to investigate and debug issues; I am comfortable with it as my day-to-day environment.

#### 3. Helm is provisioned via terraform rather than argocd

Given the nature of the task, I took the decision to directly provision superset into the cluster with the terraform helm provider.  In general I'd prefer the cluster was running argocd so that I could use something like the terraform argo provider and defineargo apps that way.  This is good enough for a play system and gives a faster turn-around.

#### 4. File upload via terraform

A real-world system would have some sort of data transform pipeline for feeding data - storing lottery numbers as a string array is not ideal.  I played with the idea of transforming the data before upload, but it wasn't clear whether that was permitted within the scope of the exercise and it would be quick to do if it became necessary.  Superset almost certainly has transform functions, but Superset's online documentation corpus is unreliable.  Therefore I took the decision to generate a simple `UNION ALL` view across the five ball number columns to generate a combined list of all winning lottery balls.  It's a pragmatic solution and it works well enough within the scope of the demo.

###### 5. IAM roles should be provisioned prior to build-out

In an ideal world I would have a good overview of what roles were necessary and prune out those that were not.  Unfortunately, some of these services e.g Glue and Athena are new to me so I'm not familiar with their required minimum credential sets.  Where possible, I've retroactively gone back to prune down iam permissions etc.

###### 6. Use of Nginx Ingress

I elected to use the NginX ingress controller primarily because it provides a reliable manner to map k8s services to a classic loadbalancer (which is what I used in this case).  I use Ingresses in my day to day role and am comfortable enough with them to troubleshoot them if there are issues.

###### 7. Postgresql should be in RDS, Redis should be in Elasticache

I don't like running stateful data stores in kubernetes - even with PVC backing and regional topology annotations. It makes more sense to me to keep data outside the cluster where possible, so I would prefer to put Postgresql and Redis into external services.  However, that is beyond the scope of this exercise and what is provided here is good enough for the small datasets in use.

###### 8. Spot instances are cheaper but they create topology issues

Because of the stateful nature of Postgresql, it requires a PersistentVolumeClaim in order to store data locally.  Unfortunately, [the initial cluster I built](https://github.com/sacrebleu/superset-demo/blob/948628d9311fd9fca5eda65d7fd8f48f41bcb04f/tf/eks.tf#L69) specified SPOT instances of a single family only, with only one instance created because of cost considerations.  When the instance was reclaimed, a replacement came up in a different AZ and the underlying volume could not be attached, leading to the system going down.  This can obviously be mitigated by widening the number of permitted instance classes in the Node Group... and by moving stateful services out of Kubernetes in the first place.

#### Meditations

1. Superset configuration required an enormous amount of trial and error; the internet is full of bad or subtly wrong config suggestions.  What worked was a service account using irsa with the necessary permissions and providing NO FURTHER GUIDANCE to the superset system about how to connect; boto3 used the assumed role and was able (finally) to connect.  In retrospect it's obvious but it was a journey of several hours to land on a working configuration.

2. It was frustrating to try to work out how to get Superset to display data in the way I wanted to.  I think of things like lottery ball picks in terms of the basic statistics I know, so to me histograms and gaussian curves make sense.  However, Superset's histogram functionality is extremely limited and the bar graph functionality is also stunted.  Much of this is likely down to nuances in dataset configuration that I do not understand in the environment, but it really should not be as hard as it is to display a histogram of five buckets, with the X axis in distinct categories. Superset tutorials are sparse and often paywalled; coming from a Grafana / SQL background it is often not the most intutive UI for me.

----

## Results

#### Statistics of the NY Lottery Dataset

###### 1: Select top 5 common winning numbers

query:

    select num, count(num) as freq
    from lottery_winning_numbers_merged
    group by num
    order by freq desc
    limit 5

results:

    #	num	freq
    1	31	217
    2	10	215
    3	20	211
    4	17	210
    5	14	210

###### 2: Calculate the Average Multiplier Value

query:

    select avg(cast(coalesce(nullif(multiplier,''),'0') as integer))
    from lottery_numbers

result:

    1.992948435434112

###### 3: Calculate the top 5 mega ball results

query:

    select count(mega_ball) as cnt, mega_ball
    from lottery_numbers
    group by mega_ball
    order by cnt desc
    limit 5

result:

    #	cnt	mega_ball
    1	88	10
    2	88	7
    3	87	9
    4	86	13
    5	85	15

###### 4. How many of the lotteries were drawn on a weekday vs weekend

weekday query:

    select count(*) from (
        select  case when day_of_week(date_parse(draw_date, '%m/%d/%Y')) > 5 then 0 else 1 end as d
        from lottery_numbers) as d
    where d = 1

    #	_col0
    1	2269

weekend query:

    select count(*) from (
    select  case when day_of_week(date_parse(draw_date, '%m/%d/%Y')) > 5 then 0 else 1 end as d
    from lottery_numbers) as d
    where d = 1

    #	_col0
    1	0

Result: all lotteries were run during the week (specifically on Tuesdays and Fridays)

#### Some interesting patterns I noticed

On the statistics themselves; ball 1, ball 5 and the mega ball all seem to display sample curves that seem suspicious at first glance.  

Ball 1 could be interpreted as a normal distribution that just happens to be skewed very heavily towards the lower end of the scale, which is plausible given that the Ball 1 column contains the results of SORTED lottery number data, therefore Ball 1 will always tend to the lower end of the scale.  However, this very strong binding to the numbers 1 - 4 feels biassed.

![image: Ball 1 distribution](./images/ball-1-distribution.jpg "Ball 1 number distribution")

Ball 5 has two distinct peaks, something which seems anomalous in the context of the normal curve I'd expect.  This could be a sign of a change in the range of numbers appearing on a ball; there could be a point in the draw history where the numbers change. 

![image: Ball 5 distribution](./images/ball-5-distribution.jpg "Ball 5 number distribution")

In fact, when I dug into the numbers, it appears that the range of numbers in the Lottery has changed several times in its history:

![image: Ball 5 Historical Draw Values](./images/historical-max-ball5-value.jpg "Ball 5 number historical distribution")

The mega ball is roughly twice as likely to be 20 or less than it is to be 21 or above.  

![image: Mega Ball distribution](./images/mega_ball.jpg "Mega Ball number distribution")

Perhaps there's a similar discontinuity in its numbers that could explain this

![image: Mega Ball Historical Values](./images/mega-ball-historical-values.jpg "Mega Ball Historical Values")

And yes - it seems there are several changes in the Mega Ball range over the duration of the Lottery.

Finally, there's a noticeable taper towards the frequency of the upper numbers when all the balls are investigated simultaneously, with balls of value > 56 being noticeably under-represented in the overall dataset

![image: Winning Number Frequency Distribution](./images/winning-number-freqs.jpg "Winning ball number distribution")

But again, this will be explained by the changes in data range over the course of the Lottery's existence.  

It would be very interesting to see the result distributions for the data in the order of ball drawing, rather than sorted from smallest to largest as the dataset is currently sorted, as this would also show if there was any bias in number selection.