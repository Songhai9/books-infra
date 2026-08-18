resource "aws_security_group" "kubernetes_control_plane" {
  name_prefix            = "${local.name_prefix}-k8s-control-plane-"
  description            = "Network access for the kubeadm control plane"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = {
    Name = "${local.name_prefix}-k8s-control-plane-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "kubernetes_worker" {
  name_prefix            = "${local.name_prefix}-k8s-worker-"
  description            = "Network access for kubeadm worker nodes"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = {
    Name = "${local.name_prefix}-k8s-worker-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_control_plane_ssh" {
  security_group_id = aws_security_group.kubernetes_control_plane.id
  description       = "SSH from the administrator public IPv4 address"
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_api_from_admin" {
  security_group_id = aws_security_group.kubernetes_control_plane.id
  description       = "Kubernetes API from the administrator public IPv4 address"
  cidr_ipv4         = var.admin_cidr
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_control_plane_self" {
  security_group_id            = aws_security_group.kubernetes_control_plane.id
  description                  = "Internal traffic between control-plane nodes"
  referenced_security_group_id = aws_security_group.kubernetes_control_plane.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_control_plane_from_worker" {
  security_group_id            = aws_security_group.kubernetes_control_plane.id
  description                  = "Internal Kubernetes and CNI traffic from workers"
  referenced_security_group_id = aws_security_group.kubernetes_worker.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "kubernetes_control_plane_all_ipv4" {
  security_group_id = aws_security_group.kubernetes_control_plane.id
  description       = "Allow the control plane to initiate outbound connections"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_worker_ssh" {
  security_group_id = aws_security_group.kubernetes_worker.id
  description       = "SSH from the administrator public IPv4 address"
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_worker_http" {
  security_group_id = aws_security_group.kubernetes_worker.id
  description       = "HTTP access to future Kubernetes workloads"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_worker_https" {
  security_group_id = aws_security_group.kubernetes_worker.id
  description       = "HTTPS access to future Kubernetes workloads"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_worker_gateway_http" {
  security_group_id = aws_security_group.kubernetes_worker.id
  description       = "Public HTTP access to the Envoy Gateway NodePort"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.kubernetes_gateway_http_node_port
  ip_protocol       = "tcp"
  to_port           = var.kubernetes_gateway_http_node_port
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_worker_self" {
  security_group_id            = aws_security_group.kubernetes_worker.id
  description                  = "Internal traffic between worker nodes"
  referenced_security_group_id = aws_security_group.kubernetes_worker.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_worker_from_control_plane" {
  security_group_id            = aws_security_group.kubernetes_worker.id
  description                  = "Internal Kubernetes and CNI traffic from the control plane"
  referenced_security_group_id = aws_security_group.kubernetes_control_plane.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "kubernetes_worker_all_ipv4" {
  security_group_id = aws_security_group.kubernetes_worker.id
  description       = "Allow workers to initiate outbound connections"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "kubernetes_control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.kubernetes_control_plane_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.kubernetes_control_plane.id]
  key_name               = aws_key_pair.admin.key_name
  monitoring             = false

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.kubernetes_root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.name_prefix}-k8s-control-plane-root"
    }
  }

  tags = {
    Name = "${local.name_prefix}-k8s-control-plane"
    Role = "kubernetes-control-plane"
  }
}

resource "aws_eip" "kubernetes_control_plane" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-k8s-control-plane-eip"
  }
}

resource "aws_eip_association" "kubernetes_control_plane" {
  allocation_id = aws_eip.kubernetes_control_plane.id
  instance_id   = aws_instance.kubernetes_control_plane.id
}

resource "aws_instance" "kubernetes_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.kubernetes_worker_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.kubernetes_worker.id]
  key_name               = aws_key_pair.admin.key_name
  monitoring             = false

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.kubernetes_root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.name_prefix}-k8s-worker-root"
    }
  }

  tags = {
    Name = "${local.name_prefix}-k8s-worker"
    Role = "kubernetes-worker"
  }
}
