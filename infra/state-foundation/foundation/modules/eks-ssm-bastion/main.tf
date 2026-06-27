# SSM-managed bastion for reaching the PRIVATE foundation EKS API endpoint (CZID #341, mirrors #322).
# No SSH, no public IP, no inbound: operators connect via SSM Session Manager
#   aws ssm start-session --target <bastion_instance_id>
# and run kubectl against the private endpoint. Lives in a private subnet whose NAT egress reaches the
# SSM + EKS endpoints on 443. Must be deployed together with endpoint_public_access=false (lockout otherwise).

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name_prefix        = "${var.name}-eks-bastion-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${var.name}-eks-bastion-"
  role        = aws_iam_role.bastion.name
  tags        = var.tags
}

resource "aws_security_group" "bastion" {
  name_prefix = "${var.name}-eks-bastion-"
  description = "SSM bastion for private EKS API access (egress-only)"
  vpc_id      = var.vpc_id
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.bastion.id
  description       = "HTTPS egress (SSM endpoints + EKS API)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow the bastion to reach the EKS control-plane API (443) on the cluster security group.
resource "aws_vpc_security_group_ingress_rule" "cluster_from_bastion" {
  security_group_id            = var.cluster_security_group_id
  description                  = "EKS API from the SSM bastion (CZID #341)"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_instance" "bastion" {
  ami                         = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = false
  monitoring                  = true # CKV_AWS_126
  ebs_optimized               = true # CKV_AWS_135

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2
  }

  root_block_device {
    encrypted   = true
    volume_size = 8
    volume_type = "gp3"
  }

  tags = merge(var.tags, { Name = "${var.name}-eks-ssm-bastion" })
}
