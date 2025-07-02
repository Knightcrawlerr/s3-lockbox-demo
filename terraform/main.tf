terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  availability_zones = ["${var.region}a", "${var.region}b"]
  name_prefix        = "lockbox"
}

resource "aws_vpc" "lockbox_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-lockbox-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_subnet" {
  count = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.lockbox_vpc.id
  cidr_block = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(local.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_subnet" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.lockbox_vpc.id
  cidr_block = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(local.availability_zones, count.index)

  tags = {
    Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lockbox_vpc.id

  tags = {
    Name = "${local.name_prefix}-igw"
    Environment = var.environment
  }
}

resource "aws_eip" "s3_lockbox_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "s3_lockbox_nat_gateway" {
  allocation_id = aws_eip.s3_lockbox_eip.id
  subnet_id    = aws_subnet.public_subnet[0].id

  tags = {
    Name        = "${local.name_prefix}-nat-gateway"
    Environment = var.environment
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lockbox_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.lockbox_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.s3_lockbox_nat_gateway.id
  }

  tags = {
    Name = "${local.name_prefix}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  count = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_association" {
  count = length(var.private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_vpc_endpoint" "lockbox_vpce" {
  vpc_id       = aws_vpc.lockbox_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public_rt.id,
    aws_route_table.private_rt.id
  ]

  tags = {
    Name        = "${local.name_prefix}-lockbox-vpce"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "s3_lockbox_demo_policy" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["arn:aws:s3:::s3-lockbox-demo/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::s3-lockbox-demo"]
  }
}

resource "aws_iam_policy" "s3_lockbox_demo_policy" {
  name        = "s3_lockbox_demo_policy"
  description = "Policy to allow S3 upload access"

  policy      = data.aws_iam_policy_document.s3_lockbox_demo_policy.json

}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "s3_lockbox_demo_role" {
  name               = "s3_lockbox_demo_role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_role_policy_attachment" "s3_lockbox_demo_role_policy_attachment" {
  role       = aws_iam_role.s3_lockbox_demo_role.name
  policy_arn = aws_iam_policy.s3_lockbox_demo_policy.arn
}


resource "aws_s3_bucket" "lockbox_bucket" {
  bucket = "s3-lockbox-demo"
  force_destroy = true

  tags = {
    Name        = "${local.name_prefix}-lockbox-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "lockbox_bucket_versioning" {
  bucket = aws_s3_bucket.lockbox_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "lockbox_bucket_public_access_block" {
  bucket = aws_s3_bucket.lockbox_bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "s3_lockbox_demo_bucket_policy" {
  statement {
    sid = "DenyUnlessVPCE"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = ["arn:aws:s3:::s3-lockbox-demo/*", "arn:aws:s3:::s3-lockbox-demo"]
    condition {
      test     = "StringNotEqualsIfExists"
      variable = "aws:PrincipalArn"
      values   = [var.admin_user_arn]
    }
    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values = [aws_vpc_endpoint.lockbox_vpce.id]
    }
  }
  statement {
    sid = "AllowEC2RoleAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.s3_lockbox_demo_role.arn]
    }
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["arn:aws:s3:::s3-lockbox-demo/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.lockbox_vpce.id]
    }
  }
  statement {
    sid = "AllowAdminUserAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [var.admin_user_arn]
    }
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::s3-lockbox-demo", "arn:aws:s3:::s3-lockbox-demo/*"]
  }
  
}

resource "aws_s3_bucket_policy" "lockbox_bucket_policy" {
  bucket = aws_s3_bucket.lockbox_bucket.id

  policy = data.aws_iam_policy_document.s3_lockbox_demo_bucket_policy.json
}


resource "aws_iam_instance_profile" "s3_lockbox_demo_instance_profile" {
  name = "s3_lockbox_demo_instance_profile"

  role = aws_iam_role.s3_lockbox_demo_role.name
}

resource "aws_security_group" "s3_lockbox_demo_security_group" {
  name        = "${local.name_prefix}-lockbox-sg"
  vpc_id      = aws_vpc.lockbox_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.s3_lockbox_demo_lb_security_group.id]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    security_groups = [aws_security_group.s3_lockbox_bastion_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-lockbox-sg"
    Environment = var.environment
  }
}


resource "aws_launch_template" "s3_lockbox_demo_launch_template" {
  name_prefix   = "lockbox-launch-template-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.s3_lockbox_demo_security_group.id]


  iam_instance_profile {
    name = aws_iam_instance_profile.s3_lockbox_demo_instance_profile.name
  }

  user_data = base64encode(templatefile("scripts/user_data.sh", {
    bucket_name = aws_s3_bucket.lockbox_bucket.bucket
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name_prefix}-lockbox-instance"
      Environment = var.environment
    }
  }
}


resource "aws_autoscaling_group" "s3_lockbox_demo_asg" {
  launch_template {
    id      = aws_launch_template.s3_lockbox_demo_launch_template.id
    version = aws_launch_template.s3_lockbox_demo_launch_template.latest_version
  }

  min_size     = 2
  max_size     = 4
  desired_capacity = 2

  vpc_zone_identifier = aws_subnet.private_subnet[*].id

}



resource "aws_security_group" "s3_lockbox_demo_lb_security_group" {
  name        = "${local.name_prefix}-lb-sg"
  vpc_id     = aws_vpc.lockbox_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-lb-sg"
    Environment = var.environment
  }
}

resource "aws_lb" "s3_lockbox_demo_lb" {
  name               = "${local.name_prefix}-lb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.s3_lockbox_demo_lb_security_group.id]
  
  subnets = aws_subnet.public_subnet[*].id

  enable_deletion_protection = false

  tags = {
    Name        = "${local.name_prefix}-lockbox-lb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "s3_lockbox_demo_lb_target_group" {
  name     = "${local.name_prefix}-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lockbox_vpc.id

  health_check {
    path     = "/index.php"
    protocol = "HTTP"
  }


  tags = {
    Name        = "${local.name_prefix}-lockbox-lb-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "s3_lockbox_demo_lb_listener" {
  load_balancer_arn = aws_lb.s3_lockbox_demo_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.s3_lockbox_demo_lb_target_group.arn
  }
}

resource "aws_autoscaling_attachment" "s3_lockbox_demo_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.s3_lockbox_demo_asg.name
  lb_target_group_arn    = aws_lb_target_group.s3_lockbox_demo_lb_target_group.arn
}


resource "aws_security_group" "s3_lockbox_bastion_security_group" {
  name        = "${local.name_prefix}-bastion-sg"
  vpc_id     = aws_vpc.lockbox_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-bastion-sg"
    Environment = var.environment
  }
}

resource "aws_instance" "bastion" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.public_subnet[0].id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.s3_lockbox_bastion_security_group.id]

  tags = {
    Name        = "${local.name_prefix}-bastion-instance"
    Environment = var.environment
  }
}
