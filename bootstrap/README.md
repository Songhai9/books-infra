# Remote state bootstrap

This stack owns the S3 bucket used by every Terraform backend in this
repository. The bucket is private, versioned, encrypted with SSE-S3, and
protected against accidental Terraform deletion.

The bucket and its backend have a bootstrap dependency: the bucket must exist
before Terraform can initialize the S3 backend that stores this stack's state.
The initial creation was therefore performed locally, followed by
`terraform init -migrate-state`. Normal operations now use the remote backend.

## Normal validation

```bash
aws login --profile books-admin
AWS_PROFILE=books-admin terraform init
AWS_PROFILE=books-admin terraform plan
```

The expected result after initialization is `No changes`.

## Disaster recovery

Do not recreate or delete the bucket if backend initialization fails. Confirm
that the bucket exists, restore a previous object version if necessary, and use
the pre-migration state backup or `terraform import` only as a last resort.
