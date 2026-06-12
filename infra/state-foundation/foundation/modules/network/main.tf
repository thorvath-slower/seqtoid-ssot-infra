# =============================================================================
# foundation/modules/network — VPC, subnets, IGW, NAT, route tables
# -----------------------------------------------------------------------------
# The shared network the whole CZ ID stack runs in. The foundation owns it; no
# downstream stack defines a VPC. Subnets are tagged for EKS load-balancer
# discovery so the cluster module (and in-cluster controllers) can find them.
#
# Portability note: this is the CLOUD-edition foundation. The k3s appliance
# edition has no VPC/subnets — it runs on a single node — so this whole module
# is cloud-only and is selected out of the appliance profile upstream.
# =============================================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

locals {
  # /16 split into /20s: public subnets at the bottom, private above them.
  public_cidrs  = [for i in range(length(var.azs)) : cidrsubnet(var.cidr, 4, i)]
  private_cidrs = [for i in range(length(var.azs)) : cidrsubnet(var.cidr, 4, i + 8)]

  # One NAT in dev (cost) vs one-per-AZ in prod (HA). Index private RTs to a NAT.
  nat_count = var.single_nat_gateway ? 1 : length(var.azs)

  tags = merge(var.tags, { "Module" = "network" })
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${var.name}-vpc" })

  # The shared VPC is foundational — never let a stray plan delete it.
  lifecycle {
    prevent_destroy = true
  }
}

# Lock down the VPC's default security group: no ingress, no egress, so nothing
# can accidentally rely on it (CKV2_AWS_12). Managing it adopts it and strips all
# rules; workloads use purpose-built SGs instead.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-default-sg-locked" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-igw" })
}

# --- Public subnets (ALB / NAT live here) ------------------------------------
resource "aws_subnet" "public" {
  # checkov:skip=CKV_AWS_130:Public ingress subnet by design — the ALB and NAT
  # gateways live here and require public IP assignment. Workloads run in the
  # private subnets; nodes are never placed here.
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name                                        = "${var.name}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# --- Private subnets (workloads / EKS nodes live here) -----------------------
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.tags, {
    Name                                        = "${var.name}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# --- NAT egress for private subnets ------------------------------------------
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${var.name}-nat-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(local.tags, { Name = "${var.name}-nat-${count.index}" })
  depends_on    = [aws_internet_gateway.this]
}

# --- Routing -----------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }
  tags = merge(local.tags, { Name = "${var.name}-private-rt-${count.index}" })
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
