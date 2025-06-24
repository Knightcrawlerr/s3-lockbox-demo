provider "aws" {
  region = var.aws_region
  
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

resource "aws_vpc" "lockbox_vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "s3_lockbox_demo_vpc"
  }
  
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.lockbox_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.lockbox_route_table.id]
}

resource "aws_subnet" "lockbox_subnet" {
  vpc_id            = aws_vpc.lockbox_vpc.id
  cidr_block        = var.subnet_cidr_block
  map_public_ip_on_launch = true
  availability_zone = var.availability_zone

  tags = {
    Name = "s3_lockbox_demo_subnet"
  }
}

resource "aws_internet_gateway" "lockbox_gateway" {
  vpc_id = aws_vpc.lockbox_vpc.id

  tags = {
    Name = "s3_lockbox_demo_gateway"
  }
}

resource "aws_route_table" "lockbox_route_table" {
  vpc_id = aws_vpc.lockbox_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lockbox_gateway.id
  }

  tags = {
    Name = "s3_lockbox_demo_route_table"
  }
}

resource "aws_route_table_association" "lockbox_route_table_association" {
  subnet_id      = aws_subnet.lockbox_subnet.id
  route_table_id = aws_route_table.lockbox_route_table.id
}

resource "aws_security_group" "lockbox_security_group" {
  vpc_id = aws_vpc.lockbox_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "s3_lockbox_demo_security_group"
  }
}


resource "aws_s3_bucket" "lockbox_bucket" {
  bucket = "s3-lockbox-demo"
  force_destroy = true

  tags = {
    Name = "s3_lockbox_demo_bucket"
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
      values = [aws_vpc_endpoint.s3.id]
    }
  }
  statement {
    sid = "AllowEC2RoleAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [var.demo_s3_upload_role_arn]
    }
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["arn:aws:s3:::s3-lockbox-demo/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.s3.id]
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

resource "aws_iam_instance_profile" "lockbox_instance_profile" {
  name = "s3_lockbox_demo_instance_profile"
  role = aws_iam_role.s3_lockbox_demo_role.name
  
}

resource "aws_instance" "lockbox_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.lockbox_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.lockbox_security_group.id]
  iam_instance_profile = aws_iam_instance_profile.lockbox_instance_profile.name

  tags = {
    Name = "s3_lockbox_demo_instance"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = self.public_ip
    timeout     = "4m"
  }

  provisioner "file" {
    source      = "../php-app"
    destination = "/tmp/php-app"

  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y unzip apache2 php php-cli php-xml php-mbstring php-curl php-zip",
      "sudo systemctl enable apache2",
      "sudo systemctl start apache2",
      "sudo mv /tmp/php-app/* /var/www/html/",
      "sudo curl -L -o /var/www/html/aws.phar 'https://docs.aws.amazon.com/aws-sdk-php/v3/download/aws.phar'",
      "sudo mkdir -p /var/www/html/temp",
      "sudo chown -R www-data:www-data /var/www/html/temp",
      "sudo chmod 750 /var/www/html/temp"
    ]
  }
}




