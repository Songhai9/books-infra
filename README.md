# Books Infrastructure

Infrastructure as Code for the Book Notes application. This repository will
provision AWS resources with Terraform and configure the resulting hosts with
Ansible.

The project intentionally starts with a minimal foundation. The current phase
does not create any AWS resources and therefore does not generate infrastructure
costs.

## Repository structure

```text
.
├── .github/workflows/  # Continuous integration workflows
├── ansible/            # Host configuration (introduced in a later phase)
├── bootstrap/          # S3 backend used to store and lock Terraform states
└── terraform/          # AWS network and infrastructure definitions
```

## Prerequisites

- Terraform 1.15.x
- Ansible Core 2.21.x
- AWS CLI v2
- An authenticated AWS CLI profile named `books-admin`

Authenticate with temporary credentials before running Terraform locally:

```bash
aws login --profile books-admin
aws sts get-caller-identity --profile books-admin
```

## Validate Terraform locally

The validation commands initialize the AWS provider and check the Terraform
files. They do not call `terraform apply`.

```bash
cd terraform
terraform fmt -check -recursive
terraform init
terraform validate
```

Copy the example variables file and replace its documentation-only address with
your current public IPv4 address in `/32` notation:

```bash
cp terraform.tfvars.example terraform.tfvars
```

The local `terraform.tfvars` file is ignored by Git. Preview the network changes
with the authenticated AWS profile:

```bash
AWS_PROFILE=books-admin terraform plan
```

The network plan creates a VPC (`10.10.0.0/16`), one public subnet
(`10.10.1.0/24`), an Internet Gateway, public routing, and an application
Security Group. SSH is restricted to `admin_cidr`, HTTP is public on port 80,
and PostgreSQL is not exposed.

This phase does not create an EC2 instance, NAT Gateway, load balancer, or public
IPv4 address. Review a saved plan before running any future `terraform apply`.

## Cost controls

The AWS account has a monthly cost budget named `books-infra-monthly` with a
limit of USD 10 and alerts at USD 1, 5, 8, and 10.

AWS Budgets sends notifications but does not block resource creation. Disposable
lab infrastructure must therefore be removed with `terraform destroy` after use,
and the AWS console must be checked for remaining instances, volumes, and public
IPv4 addresses.

## Terraform state

Terraform states are stored in the private, versioned, and encrypted S3 bucket
`songhai9-books-infra-tfstate-eu-west-3`:

```text
bootstrap/terraform.tfstate
books/dev/terraform.tfstate
```

The S3 backend uses native lockfiles to prevent concurrent writes. DynamoDB is
not required. Local state files, backend metadata, plans, and variable values
remain excluded from Git.

The `bootstrap/` configuration owns the state bucket itself. Its
`prevent_destroy` lifecycle rule protects the bucket from an accidental
`terraform destroy`.
