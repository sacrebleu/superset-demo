# Superset Investigation of NY Powerball Lottery numbers
#### Author: Sacrebleu, 2024

### Prerequisites

1. Terraform 1.7.x
2. git
3. awscli

#### Tl;Dr How to run

###### Precursors

    $ export AWS_ACCESS_KEY_ID=<access key>
    $ export AWS_SECRET_ACCESS_KEY=<secret key>

###### Initial Infrastructure Build

    $ cd ./tf
    $ terraform init
    $ terraform plan -out plan.out 
    $ terraform apply -plan plan.out

###### Helm application provisioning

some values need to be set as locals e.g the cluster name and the oidc provider.  These could be derived with more work.

    $ cd ./helm
    $ terraform init
    $ terraform plan -out plan.out 
    $ terraform apply -plan plan.out

###### Post-terraform steps

Some manual configuration was necessary.

1.  There is a chicken and egg problem on the IAM roles for the superset user that I didn't have time to properly solve - namely, the kms key used for data encryption and decryption is created at eks cluster time, but the IAM role for the user is created as part of the helm setup.  It would probably be better to do IAM prior to infra build but this was a problem that emerged while I was working on the demo and I couldn't devote the time to go back and rearrange everything.  Thus, the KMS key policy needs manual amending to permit the superset athena role to make use of it and a reapplication of terraform will remove the policy block that grants the superuser role access to the relevant kms key[TODO]

#### Superset Configuration

The initial data table is based on the csv file upload.  However, I created some derived fields which were then complex to visualise.  I took the decision to create
a separate view for the combined winning ball numbers:


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

this leverages sql to provide a unified list of numbers which are then more amenable
to counting, placing into histograms etcetera.

### Statistics of the NY Lottery

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


### Design decisions

###### Wide-ranging roles were given to the project provisioning user

In a normal environment, I would have either used an IAM boundary policy or spent
more time locking down the roles for the terraform user, but I am not familiar enough
with Glue and Athena to guess what roles will be needed and time is short.  Therefore
I have in general used the AWS provisioned roles for service users where I could,
and inline IAM policies elsewhere.  All are allocated via a user-group for ease of management

###### Helm is provisioned via terraform rather than argocd

Given the nature of the task, I took the decision to directly provision superset into
the cluster with the terraform helm provider.  In general I'd prefer the cluster was
running argocd so that I could use something like the terraform argo provider and defineargo apps that way.  This is good enough for a play system and gives a faster turn-around.

###### File upload via terraform

Again, a real-world system would have some sort of data transform pipeline for feeding data - storing lottering numbers as a string array is not ideal.  I played with the idea of transforming the data before upload, but it wasn't clear whether that was
permitted within the scope of the exercise and it would be quick to do if it became
necessary.  Superset has transform functions which seem adequate on top of athena.

###### IAM roles should be provisioned prior to build-out

In an ideal world I would have a good overview of what roles were necessary and prune
out those that were not.  Unfortunately, some of these services [Glue, Athena] are new to me so I'm not familiar with their required minimum credential sets.  Where possible.

I've retroactively gone back to prune down iam permissions etc.

###### Use of Nginx Ingress

I elected to use the NginX ingress controller primarily because it provides a reliable
manner to map k8s services to a classic loadbalancer (which is what is used in this case).

#### Meditations

1. superset configuration required an enormous amount of trial and error; the internet is full of bad or subtly wrong config suggestions.  What worked was a service account using irsa with the necessary permissions and providing NO FURTHER GUIDANCE to the superset system about how to connect; boto3 used the assumed role and was able (finally) to connect.  In retrospect it's obvious but it was a journey of several hours to land on a working configuration.
