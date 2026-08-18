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
└── terraform/          # AWS infrastructure definitions
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

The bootstrap configuration only initializes the AWS provider and validates the
Terraform files. It does not call `terraform apply`.

```bash
cd terraform
terraform fmt -check -recursive
terraform init
terraform validate
```

When AWS access is required in a later phase, select the profile explicitly:

```bash
AWS_PROFILE=books-admin terraform plan
```

## Cost controls

The AWS account has a monthly cost budget named `books-infra-monthly` with a
limit of USD 10 and alerts at USD 1, 5, 8, and 10.

AWS Budgets sends notifications but does not block resource creation. Disposable
lab infrastructure must therefore be removed with `terraform destroy` after use,
and the AWS console must be checked for remaining instances, volumes, and public
IPv4 addresses.

## Terraform state

Terraform state is local during the bootstrap phase and is excluded from Git.
A remote backend will be introduced separately before collaborative or automated
deployments.
