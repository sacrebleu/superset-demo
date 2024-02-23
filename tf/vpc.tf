// provision a vpc with internet gateway + nat, 3 public subnets, 3 private subnets, and the route tables
// to bind them
//
// should give a base platform for infrastructure build out
resource aws_vpc demo_vpc {
  cidr_block = var.vpc_cidr_range // class C should be ample
  region = data.aws_region.deployment_region.name

  tags = local.tags
}

// create the public subnets
resource aws_subnet demo_public_subnet {
  for_each = var.public_subnets
  vpc_id = aws_vpc.demo_vpc.id

  map_public_ip_on_launch = true
  cidr_block = each.value
  availability_zone_id = each.key

  tags = merge(local.tags, { type = public })
}

// create the private subnets
resource aws_subnet demo_private_subnet {
  for_each = var.private_subnets
  vpc_id = aws_vpc.demo_vpc.id

  map_public_ip_on_launch = false
  cidr_block = each.value
  availability_zone_id = each.key

  tags = merge(local.tags, { type = private })
}

// internet gateway so we can actually reach the public internet
resource aws_internet_gateway internet_gateway {
  vpc_id = aws_vpc.demo_vpc.id
  tags = merge(local.tags, { name = "project internet gateway"})
}

// public side
// route table to permit public subnets to reach the internet gateway
resource aws_route_table internet_routes {
  vpc_id = aws_vpc.demo_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = merge(local.tags, { name = "demo internet route table"})
}
// and associate it with the public subnets
resource aws_route_table_association internet_routing {
  for_each = aws_subnet.demo_public_subnet

  subnet_id = each.value.id
  route_table_id = aws_route_table.internet_routes.id
}

// private side
resource aws_eip nat_eip {
  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]
}

// single nat gateway
resource aws_nat_gateway nat {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.demo_public_subnet.*.id, 0)
  depends_on    = [aws_internet_gateway.internet_gateway]
  tags = merge(local.tags, {name = "project nat gateway"})
}

// private routing table
resource aws_route_table private_routes {
  vpc_id = aws_vpc.demo_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
  tags = merge(local.tags, { name = "demo private route table"})
}
// and associate it with the private subnets
resource aws_route_table_association nat_routing {
  for_each = aws_subnet.demo_private_subnet

  subnet_id = each.value.id
  route_table_id = aws_route_table.private_routes.id
}

resource "aws_security_group" "default" {
  name        = "${local.name}-default"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = aws_vpc.demo_vpc.id
  depends_on  = [aws_vpc.demo_vpc]
  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }
  tags = local.tags
}

