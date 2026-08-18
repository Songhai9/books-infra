# Books Infrastructure

Infrastructure as Code for the Book Notes application. This repository will
provision AWS resources with Terraform and configure the resulting hosts with
Ansible.

The project intentionally grows in small, reviewable phases. It currently
contains the AWS network, a standalone application host, and a two-node kubeadm
cluster configured idempotently with Ansible.

## Repository structure

```text
.
├── .github/workflows/  # Continuous integration workflows
├── ansible/            # Idempotent Docker and Kubernetes configuration
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

The infrastructure contains a VPC (`10.10.0.0/16`), one public subnet
(`10.10.1.0/24`), an Internet Gateway, public routing, an application Security
Group, and one Ubuntu 24.04 EC2 instance. SSH is restricted to `admin_cidr`, HTTP
is public on port 80, and PostgreSQL is not exposed.

The EC2 instance uses a cost-conscious T3 size with standard CPU credits,
requires IMDSv2, and stores its operating system on an encrypted gp3 volume.
Only the public half of the dedicated SSH key is imported into AWS. The private
key remains on the administrator workstation.

Ansible connects to this instance over SSH, installs Docker Engine from the
official Docker repository, and deploys the versioned Book Notes application
with PostgreSQL through Docker Compose. See `ansible/README.md` for the
connectivity, deployment, check-mode, and idempotence commands.

This project does not create a NAT Gateway, load balancer, or managed database.
The kubeadm lab cluster is provisioned directly on EC2. Review a saved plan
before every `terraform apply`.

## Kubeadm lab architecture

The Kubernetes infrastructure adds one `t3.small` control-plane node and one
`t3.small` worker node in the existing public subnet. Both nodes use encrypted
20 GiB gp3 root volumes and standard T3 CPU credits. The control plane receives
a stable Elastic IP for the Kubernetes API; the worker keeps an ephemeral public
address for initial Ansible administration.

Separate Security Groups expose SSH and the Kubernetes API only to
`admin_cidr`. Future HTTP and HTTPS workloads are accepted on the worker. All
other Kubernetes and CNI traffic is limited to references between the two node
Security Groups.

The first Gateway API deployment exposes Envoy through worker NodePort `30080`.
Terraform opens only that explicit NodePort instead of the complete Kubernetes
NodePort range.

Ansible installs Kubernetes `v1.36.3` with containerd, initializes the cluster
with kubeadm, deploys Flannel for pod networking, and joins the worker over the
private VPC network. Package versions are pinned and held; a second playbook run
converges with no changes. See `ansible/README.md` for the role boundaries,
verification commands, and upgrade warning.

The standalone Compose host is stopped while the cluster is running to avoid
unnecessary simultaneous compute charges. Its EBS data remains preserved. The
cluster nodes must be destroyed after lab sessions when their state does not
need to persist.

## Kubernetes continuous deployment access

Terraform creates two distinct IAM identities for the deployment path:

- the control-plane instance profile attaches `AmazonSSMManagedInstanceCore`,
  which registers the EC2 instance as a Systems Manager managed node; and
- the GitHub CD role trusts only the immutable OIDC subject for the
  `Songhai9/books-k8s` repository's `main` branch and version tags matching
  `v*.*.*` from the immutable `Songhai9/books` repository identity.

The GitHub role can send only the `AWS-RunShellScript` document to the exact
control-plane instance and read that command's result. It cannot open an SSH
session, modify EC2 resources, or send commands to another instance. GitHub
Actions exchanges its OIDC token for temporary AWS credentials, so no AWS
access key is stored in GitHub.

The application release workflow can therefore call the reusable Kubernetes
deployment workflow only after publishing and smoke-testing a versioned image.
Branches, pull requests, and non-version tags from the application repository
cannot assume the deployment role.

After applying this configuration, copy
`github_kubernetes_cd_role_arn` and
`kubernetes_control_plane_instance_id` to the matching non-secret repository
variables in `Songhai9/books-k8s`. Ansible installs the pinned Helm client on
the control plane; the deployment workflow then invokes Helm through Systems
Manager from inside the cluster network.

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
