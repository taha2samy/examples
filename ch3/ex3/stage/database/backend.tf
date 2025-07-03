terraform {
  backend "s3" {
    key            = "ex3/stage/database/terraform.tfstate"
  }
}