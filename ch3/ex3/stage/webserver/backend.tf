terraform {
  backend "s3" {
    key            = "ex3/stage/webserver/terraform.tfstate"
  }
}