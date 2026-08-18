data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_key_pair" "admin" {
  key_name   = "${local.name_prefix}-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name = "${local.name_prefix}-admin-key"
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.admin.key_name
  monitoring             = false

  # Standard mode prevents unexpected T3 surplus CPU credit charges.
  credit_specification {
    cpu_credits = "standard"
  }

  # Require session-oriented credentials instead of allowing IMDSv1 requests.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.name_prefix}-app"
    Role = "application"
  }
}
