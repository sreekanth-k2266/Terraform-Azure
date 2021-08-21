#getting all availability zones
data "aws_availability_zones" "availability_zones" {
  state = "available"
}

#resource to create VPC
resource "aws_vpc" "vpc" {
  cidr_block                       = var.cidr_block
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = false
  tags = {
    Name = join("",[var.vpc_name,"_vpc"])
  }
}

#elastic IP for Nat gateway
resource "aws_eip" "elastic_ip" {
  vpc = true
  tags = {
    Name = join("", [var.vpc_name, "elasticip"])
  }
}

# NAT gateway is required for the internet connection in a VPC for private subnets
resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_subnet.subnets_public]
  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = element(aws_subnet.subnets_public.*.id, 0)
}

#creating route table to provide internet connection with nat gateway private routing
resource "aws_route_table" "rtb_private" {
  vpc_id = aws_vpc.vpc.id
  route {
    nat_gateway_id = element(concat(aws_nat_gateway.nat_gateway.*.id, [""]), 0)
    cidr_block     = "0.0.0.0/0"
  }
  tags = {
    Name = join("", [var.vpc_name, "_private_table"])
  }
}

#creating subnets private
resource "aws_subnet" "subnets_private" {
  count             = length(var.private_subnet_cidr)
  cidr_block        = element(var.private_subnet_cidr, count.index)
  availability_zone = element(var.azs, count.index)
  vpc_id            = aws_vpc.vpc.id
  tags = {
  type = "private",
  Name = join("", [var.vpc_name, "_private_subnet"])#,
  #"kubernetes.io/cluster/${var.cluster_name}" = "shared",
  #"kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = length(aws_subnet.subnets_private.*.id)
  route_table_id = aws_route_table.rtb_private.id
  subnet_id      = aws_subnet.subnets_private[count.index].id
}

# Internet gateway is required for the internet connection in a VPC
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = join("", [var.vpc_name, "_IGW"])
  }
}

#creating route table to provide internet connection with internet gateway public facing
resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = join("", [var.vpc_name, "_public_table"])
  }
}

#associating route table as public rtb
resource "aws_main_route_table_association" "main_route_table" {
  route_table_id = aws_route_table.rtb_public.id
  vpc_id         = aws_vpc.vpc.id
}

#creating subnets public
resource "aws_subnet" "subnets_public" {
  count             = length(var.public_subnet_cidr)
  cidr_block        = element(var.public_subnet_cidr, count.index)
  availability_zone = element(var.azs, count.index)
  vpc_id            = aws_vpc.vpc.id
  tags = {
    type = "public",
    Name = join("", [var.vpc_name, "_public_subnet"])#,
#    "kubernetes.io/cluster/${var.cluster_name}" = "shared",
#    "kubernetes.io/role/elb" = 1
  }
    map_public_ip_on_launch = true
  }
/*
data "aws_subnet_ids" "subnet_id" {
  depends_on = [aws_subnet.subnets_private]
  vpc_id = aws_vpc.eks_vpc.id
}*/
/////////////////////////////////
/*
resource "aws_security_group" "private_sg" {
  name = join("",[var.cluster_name,"privatesg"])
  vpc_id = aws_vpc.eks_vpc.id
  ingress {
    from_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.public_sg.id]
    #cidr_blocks = [aws_security_group.public_sg.id]
    to_port = 80
  }
  egress {
    from_port = 0
    protocol = "tcp"
    to_port = 0
  }
  tags = {
    Name = join("",[var.cluster_name,"privatesg"])
  }
}

resource "aws_security_group" "public_sg" {
  name = join("",[var.cluster_name,"publicsg"])
  vpc_id = aws_vpc.eks_vpc.id
  ingress {
    from_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    to_port = 80
  }
  egress {
    from_port = 0
    protocol = "tcp"
    to_port = 0
  }
  tags = {
    Name = join("",[var.cluster_name,"publicsg"])
  }
}*/
