provider "aws" {
  region = "ca-central-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bohulevych-asn3-vpc"
  }
}

resource "aws_subnet" "pub_sub1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ca-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "bohulevych-pub-sub1"
  }
}

resource "aws_subnet" "pub_sub2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ca-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "bohulevych-pub-sub2"
  }
}

resource "aws_subnet" "pri_sub1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ca-central-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "bohulevych-pri-sub1"
  }
}

resource "aws_subnet" "pri_sub2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "ca-central-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "bohulevych-pri-sub2"
  }
}

resource "aws_internet_gateway" "bohulevych_igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "bohulevych-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "bohulevych-nat-eip"
  }
}


resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.pub_sub1.id

  tags = {
    Name = "bohulevych-nat-gateway"
  }
}

# Public Route Table
resource "aws_route_table" "bohulevych_public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "bohulevych-public-rt"
  }
}

# Default Route to Internet Gateway
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.bohulevych_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.bohulevych_igw.id
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "pub_sub1_association" {
  subnet_id      = aws_subnet.pub_sub1.id
  route_table_id = aws_route_table.bohulevych_public_rt.id
}

resource "aws_route_table_association" "pub_sub2_association" {
  subnet_id      = aws_subnet.pub_sub2.id
  route_table_id = aws_route_table.bohulevych_public_rt.id
}

resource "aws_route_table" "bohulevych_private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "bohulevych-private-rt"
  }
}

resource "aws_route_table_association" "pri_sub1_association" {
  subnet_id      = aws_subnet.pri_sub1.id
  route_table_id = aws_route_table.bohulevych_private_rt.id
}

resource "aws_route_table_association" "pri_sub2_association" {
  subnet_id      = aws_subnet.pri_sub2.id
  route_table_id = aws_route_table.bohulevych_private_rt.id
}

resource "aws_route" "private_default_route" {
  route_table_id         = aws_route_table.bohulevych_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}
