variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
  
}

variable "instance_type" {
  description = "Type of EC2 instance to launch"
  default     = "t2.micro"
  
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  default     = "ami-020cba7c55df1f615" 
  
}

variable "key_name" {
  description = "Name of the key pair to use for SSH access"
  default     = "aws_login" 
  
}



variable "private_key_path" {
  description = "Path to the private key file for SSH access"
  default     = "~/aws_login.pem"
  
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
  
}

variable "subnet_cidr_block" {
  description = "CIDR block for the subnet"
  default     = "10.0.1.0/24"
  
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  default     = "us-east-1a"
  
}

variable "admin_user_arn" {
  description = "ARN of the IAM user"
  default     = "arn:aws:iam::867344441958:user/admin-001"
  
}

variable "demo_s3_upload_role_arn" {
  description = "ARN of the IAM role"
  default     = "arn:aws:iam::867344441958:role/demo-s3-upload-role"
  
}