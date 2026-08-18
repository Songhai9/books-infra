terraform {
  backend "s3" {
    bucket       = "songhai9-books-infra-tfstate-eu-west-3"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}
