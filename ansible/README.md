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
group_vars/kubernetes.yml    Pinned Kubernetes, CRI, and CNI versions
inventory/hosts.ini.example Versioned inventory template
inventory/generated.ini     Local inventory ignored by Git
kubernetes.yml               Kubeadm cluster orchestration
roles/kubernetes_common/     Shared operating-system and runtime state
roles/kubernetes_control_plane/ Control-plane initialization and CNI
roles/kubernetes_worker/     Idempotent worker join
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

After deployment, read the current public address from Terraform and verify the
endpoints. The address changes after a stop/start cycle:

```bash
APP_PUBLIC_IP="$(terraform -chdir=../terraform output -raw app_public_ip)"
curl "http://${APP_PUBLIC_IP}/health"
curl "http://${APP_PUBLIC_IP}/ready"
```

This is a minimal HTTP lab deployment. TLS and a stable domain name will be
introduced at the ingress or load-balancer layer later.

## Kubernetes cluster

`kubernetes.yml` configures the two EC2 nodes provisioned by Terraform as a
small kubeadm cluster. It deliberately remains separate from `site.yml`, which
owns the standalone Docker Compose host.

The playbook applies three layers in order:

1. `kubernetes_common` disables swap, loads the required kernel modules,
   enables packet forwarding, configures containerd as a CRI runtime with the
   `systemd` cgroup driver, and installs the pinned Kubernetes packages.
2. `kubernetes_control_plane` renders the kubeadm configuration, initializes
   the API server on the control plane's private address, installs the admin
   kubeconfig, and deploys the pinned Flannel pod network.
3. `kubernetes_worker` creates a 30-minute kubeadm bootstrap token only when a
   worker has not joined yet, joins it over the VPC private network, and waits
   until Kubernetes reports the node as Ready.

The current lab pins Kubernetes `v1.36.3`, cri-tools `v1.36.0`, and Flannel
`v0.28.8`. The APT packages are held after installation so a routine system
upgrade cannot change a node independently of the cluster upgrade procedure.

### Local inventory

Keep the real public and private addresses only in the ignored
`inventory/generated.ini` file. The versioned example shows the required
groups:

```ini
[kubernetes_control_plane]
books-dev-k8s-control-plane ansible_host=CONTROL_PLANE_PUBLIC_IP kubernetes_private_ip=CONTROL_PLANE_PRIVATE_IP

[kubernetes_workers]
books-dev-k8s-worker ansible_host=WORKER_PUBLIC_IP kubernetes_private_ip=WORKER_PRIVATE_IP
```

Read the current values from Terraform whenever an ephemeral worker address
changes:

```bash
terraform -chdir=../terraform output kubernetes_control_plane_public_ip
terraform -chdir=../terraform output kubernetes_control_plane_private_ip
terraform -chdir=../terraform output kubernetes_worker_public_ip
terraform -chdir=../terraform output kubernetes_worker_private_ip
```

### Install or reconcile the cluster

Run the connectivity and syntax checks before applying the desired state:

```bash
ansible kubernetes --module-name ping
ansible-playbook kubernetes.yml --syntax-check
ansible-playbook kubernetes.yml
```

A second execution should report `changed=0`. Kubeadm initialization is guarded
by `/etc/kubernetes/admin.conf`; worker registration is guarded by
`/etc/kubernetes/kubelet.conf`. The playbook therefore reconciles an existing
cluster instead of initializing it again.

### Operate and verify the cluster

The administrator kubeconfig lives on the control plane with mode `0600`.
Connect to the node and run kubectl as the unprivileged Ubuntu administrator:

```bash
ssh ubuntu@CONTROL_PLANE_PUBLIC_IP
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl cluster-info
```

The API server certificate includes both the private control-plane address and
its stable Elastic IP. The cluster components and workers use the private VPC
address; this avoids sending node-to-node administration traffic over the public
Internet.

Kubernetes package upgrades must be planned one minor version at a time and
must not be performed with a generic `apt upgrade`. Update the pinned versions,
follow the kubeadm upgrade order, and test the control plane before workers.
