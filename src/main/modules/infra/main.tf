resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-igw"
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Tier = "Public"
  })
}

resource "aws_subnet" "private" {
  count               = length(var.private_subnets)
  vpc_id              = aws_vpc.this.id
  cidr_block          = var.private_subnets[count.index]
  availability_zone   = element(data.aws_availability_zones.available.names, count.index)

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Tier = "Private"
  })
}

resource "aws_eip" "nat" {
  count  = 1
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-eip"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count         = 1
  allocation_id = aws_eip.nat[0].id 
  subnet_id     = aws_subnet.public[0].id 

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-gateway"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-route-table"
  })
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-route-table-${count.index + 1}"
  })
}

resource "aws_route" "private_nat_gateway" {
  count                  = length(var.private_subnets)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda functions in ${var.project_name} project"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-lambda-sg"
  })
}

resource "aws_security_group" "postgres" {
  name        = "${var.project_name}-postgres-sg"
  description = "Security group for PostgreSQL Aurora in ${var.project_name} project"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
    description     = "Allow PostgreSQL access from Lambda functions"
  }

  dynamic "ingress" {
    for_each = var.create_jumpbox ? [1] : []
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [aws_security_group.jumpbox[0].id]
      description     = "Allow PostgreSQL access from jumpbox"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-postgres-sg"
  })
}

resource "aws_security_group" "jumpbox" {
  count       = var.create_jumpbox ? 1 : 0
  name        = "${var.project_name}-jumpbox-sg"
  description = "Security group for database admin jumpbox in ${var.project_name} project"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-jumpbox-sg"
  })
}

resource "aws_security_group_rule" "jumpbox_self_ingress" {
  count               = var.create_jumpbox ? 1 : 0
  type                = "ingress"
  from_port           = 443
  to_port             = 443
  protocol            = "tcp"
  security_group_id   = aws_security_group.jumpbox[0].id
  self                = true
  description         = "Allow HTTPS from resources using the same security group (for SSM)"
}

resource "aws_iam_role" "ssm_role" {
  count = var.create_jumpbox ? 1 : 0
  name  = "${var.project_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-ssm-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count      = var.create_jumpbox ? 1 : 0
  role       = aws_iam_role.ssm_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jumpbox_profile" {
  count = var.create_jumpbox ? 1 : 0
  name  = "${var.project_name}-jumpbox-profile"
  role  = aws_iam_role.ssm_role[0].name
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "jumpbox" {
  count                  = var.create_jumpbox ? 1 : 0
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.jumpbox[0].id]
  iam_instance_profile   = aws_iam_instance_profile.jumpbox_profile[0].name

  user_data = <<-EOF
    #!/bin/bash
    amazon-linux-extras install postgresql12
    yum install -y jq

    systemctl status amazon-ssm-agent || {
      yum install -y amazon-ssm-agent
      systemctl enable amazon-ssm-agent
      systemctl start amazon-ssm-agent
    }

    echo "Installing database tools and utilities"
  EOF

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-jumpbox"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  count               = var.create_jumpbox ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private[0].id]

  security_group_ids = [
    aws_security_group.jumpbox[0].id
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  count               = var.create_jumpbox ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private[0].id]

  security_group_ids = [
    aws_security_group.jumpbox[0].id
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-ssmmessages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2messages" {
  count               = var.create_jumpbox ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private[0].id]

  security_group_ids = [
    aws_security_group.jumpbox[0].id
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-ec2messages-endpoint"
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-s3-endpoint"
  })
}
