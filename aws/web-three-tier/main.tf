data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_internet_gateway" "selected" {
    internet_gateway_id = var.default_internet_gateway
}

# ========= Locals for Global =========
locals {
  aws_region = data.aws_region.current.name
  aws_account_id = data.aws_caller_identity.current.account_id
  common_tags = {
    Owner = "nookcoder"
    Environment = "prod"
    Regions = local.aws_region
    AccountId = local.aws_account_id
  }
}

# ========= Locals for Subnet =========
locals {
  public_subnet = {
    "${var.vpc_name}-public-01" = {
      cidr_block = "10.0.30.0/24"
    }
    "${var.vpc_name}-public-02" = {
      cidr_block = "10.0.31.0/24"
    }
  }

  private_subnets = {
    "${var.vpc_name}-private-01" = {
      cidr_block = "10.0.40.0/23"
    }
    "${var.vpc_name}-private-02" = {
      cidr_block = "10.0.42.0/23"
    }
  }
}

# ========= Subnet =========
resource "aws_subnet" "public" {
  for_each = local.public_subnet
  vpc_id = data.aws_vpc.selected.id
  cidr_block = each.value.cidr_block

  tags = merge(local.common_tags, {
    Name = each.key
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets
  vpc_id = data.aws_vpc.selected.id
  cidr_block = each.value.cidr_block

  tags = merge(local.common_tags, {
    Name = each.key
  })

  depends_on = [aws_subnet.public]
}
# ========= Gateway =============
resource "aws_nat_gateway" "nat_gateway" {
  subnet_id = aws_subnet.public["${var.vpc_name}-public-01"].id
  allocation_id = var.default_eip
  tags = {
    Name = "gw NAT"
  }

  depends_on = [
    data.aws_internet_gateway.selected,
    aws_subnet.public
  ]
}

# ========= Route Table =========
resource "aws_route_table" "public_route_table" {
  vpc_id = data.aws_vpc.selected.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.selected.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-public-route-table"
  })
}

resource "aws_route_table" "private_route_table" {
  vpc_id = data.aws_vpc.selected.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-private-route-table"
  })

  depends_on = [aws_nat_gateway.nat_gateway]
}

resource "aws_route_table_association" "public_route_table_association" {
  for_each = local.public_subnet
  subnet_id = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_route_table_association" {
  for_each = local.private_subnets
  subnet_id = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private_route_table.id
}