terraform {
  backend "s3" {
    bucket = "superset-demo-sacrebleu"
    key    = "superset/helm"
    region = "eu-west-1"
  }
}