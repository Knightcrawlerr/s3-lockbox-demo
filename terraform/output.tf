output "lockbox_instance_public_ip_address" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.lockbox_instance.public_ip
  
}