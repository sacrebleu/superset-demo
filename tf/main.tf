terraform {
  backend "s3" {
    bucket = "superset-demo"
    key    = "superset/tfstate"
    region = "eu-west-1"
  }
}