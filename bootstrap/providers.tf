provider "aws" {
  region = "eu-west-3"

  default_tags {
    tags = {
      Environment = "shared"
      ManagedBy   = "terraform"
      Owner       = "oumar"
      Project     = "books"
    }
  }
}
