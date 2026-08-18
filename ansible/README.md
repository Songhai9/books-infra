# Ansible

Ansible configures the EC2 host created by Terraform. Terraform owns the AWS
resources; Ansible owns packages, services, and operating-system configuration
inside the instance.

## Core concepts

- The Mac is the **control node**: it runs Ansible and stores the private SSH
  key.
- The EC2 instance is the **managed node**: it does not need an Ansible agent.
- The **inventory** maps the logical `app` group to the current public IP.
- The **playbook** describes the desired operating-system state as ordered
  tasks.
- `become: true` runs system tasks through `sudo`; verification tasks switch
  back to the unprivileged administrator.
- **Idempotence** means repeated runs converge to `changed=0` when the host
  already matches the playbook.

## Files

```text
ansible.cfg                  Local Ansible defaults
inventory/hosts.ini.example Versioned inventory template
inventory/generated.ini     Local inventory ignored by Git
site.yml                     Docker configuration and Book Notes deployment
templates/                   Versioned Compose and environment templates
secrets/                     Local generated secrets ignored by Git
```

The generated inventory identifies the host, the remote Ubuntu user, and the
local private key used for SSH. Never commit private key contents.

## Connectivity test

Run commands from this directory so Ansible automatically reads `ansible.cfg`:

```bash
cd ansible
ansible app --module-name ping
```

`ping` does not send an ICMP packet. It opens an SSH connection, starts Python
on the managed host, and verifies that Ansible can execute a module there.

## Apply the configuration

Validate the playbook before connecting to a host:

```bash
ansible-playbook site.yml --syntax-check
```

Check mode is useful after the initial bootstrap. On a fresh host it cannot
fully simulate Docker package installation because the repository introduced by
an earlier task does not exist yet.

Configure the host:

```bash
ansible-playbook site.yml
```

Run the same command a second time. A result with `changed=0` demonstrates
idempotence: the machine already matches the desired state.

After the first successful run, check mode should also report no pending change:

```bash
ansible-playbook site.yml --check --diff
```

The playbook follows Docker's official Ubuntu repository installation method:
<https://docs.docker.com/engine/install/ubuntu/>.

Membership in the `docker` group is effectively root-level access because its
members control the Docker daemon. This lab grants it only to the restricted SSH
administrator.

## Book Notes deployment

The same playbook deploys `ghcr.io/songhai9/books:1.0.0` and PostgreSQL with
Docker Compose under `/opt/book-notes`. The database is reachable only through
the private Compose network; only application port 80 is published on the host.

The PostgreSQL password is generated once on the control node and stored in
`ansible/secrets/postgres_password`. The file is ignored by Git. Ansible installs
the value in `/opt/book-notes/.env` with mode `0600` and suppresses task output so
the secret does not appear in logs.

The SQL schema is downloaded from the matching `v1.0.0` application tag and
verified against a pinned SHA-256 checksum before Compose can use it.

After deployment, browse to the public EC2 address or verify the endpoints:

```bash
curl http://51.44.170.23/health
curl http://51.44.170.23/ready
```

This is a minimal HTTP lab deployment. TLS and a stable domain name will be
introduced at the ingress or load-balancer layer later.
