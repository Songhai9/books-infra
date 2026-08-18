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

variable "vpc_cidr" {
  description = "Private IPv4 CIDR allocated to the Book Notes VPC."
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR allocated to the public subnet."
  type        = string
  default     = "10.10.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "admin_cidr" {
  description = "Administrator IPv4 address in /32 notation allowed to use SSH."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && endswith(var.admin_cidr, "/32")
    error_message = "admin_cidr must be a valid IPv4 CIDR ending in /32."
  }
}
