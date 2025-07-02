variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
  
}

variable "environment" {
  default = "demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]

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

variable "admin_user_arn" {
  description = "ARN of the admin user"
  type        = string
  default     = "arn:aws:iam::867344441958:user/admin-001"
}

variable "private_key_path" {
  description = "Path to the private key file for SSH access"
  default     = "~/aws_login.pem"
  
}

variable "demo_s3_upload_role_arn" {
  description = "ARN of the IAM role"
  default     = "arn:aws:iam::867344441958:role/demo-s3-upload-role"
  
}
