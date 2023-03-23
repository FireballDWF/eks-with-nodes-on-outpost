terraform {
  backend "s3" {
    bucket = "filiatra-terraformstate"
    key    = "eks-with-nodes-on-outpost"
    region = "us-west-2"
  }
}
