variable "aws_region" {
  description = "AWS region in which the Book Notes infrastructure is created."
  type        = string
  default     = "eu-west-3"
}

variable "default_tags" {
  description = "Tags automatically added to every supported AWS resource."
  type        = map(string)

  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "oumar"
    Project     = "books"
  }
}
