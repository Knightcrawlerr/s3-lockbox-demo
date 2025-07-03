# Secure S3 File Upload Demo on AWS using PHP and Terraform

This project provisions a secure and scalable environment on AWS to upload and retrieve files using a PHP web application running on EC2. The architecture uses best practices for security, network isolation, and access control.

## Architecture Overview

### Security Design Highlights
- **Private EC2 instances in Auto Scaling Group** with a Load Balancer (ALB)
- **VPC S3 Gateway Endpoint** to restrict access to S3
- **S3 bucket policy** to allow access only from VPC Endpoint and admin IAM user
- **IAM Role** attached to EC2 via instance profile for secure access to S3
- **Public Bastion Host** for controlled SSH access

### Components
- **VPC**: Public and Private Subnets (across 2 AZs)
- **Internet Gateway & NAT Gateway**: Outbound access from private subnets
- **ALB**: Routes public HTTP traffic to private EC2 instances
- **EC2 Instances**: Host PHP upload app, managed by Auto Scaling Group
- **Bastion Host**: For debugging or SSH access to private instances
- **S3 Bucket**: Encrypted, versioned, and access-controlled

  
## Key Features

 Upload files to S3 via a PHP application using:
  - **Server-Side Encryption (SSE)** using AWS-managed KMS keys
  - **Client-Side AES-256 Encryption** before upload
- File validation (MIME type & extension check)
- Upload metadata (e.g., `username` or `ID`) to enable filtered retrieval
- Temporary file storage for download with **auto-deletion**
- Access-controlled via IAM Role attached to EC2
- S3 Bucket access via **VPC Endpoint** — no public internet traffic
- Deployed using **Terraform**: EC2, IAM, VPC, S3 setup included



## How It Works

### Upload

1. User uploads a file with a `username/ID` and selects encryption mode.
2. The file is validated (MIME + extension check).
3. It is saved temporarily to `/var/www/html/temp`.
4. If **client-side encryption** is selected:
   - AES-256-CBC encryption is applied using a fixed key (stored in `.env`).
   - IV + encrypted payload is saved as the object.
5. The file is uploaded to S3 under:
   - `sse-upload/<user_id>/<file>` or
   - `client-upload/<user_id>/<file>`

### View Uploads

1. User enters their ID.
2. App lists all files under both `sse-upload/<id>/` and `client-upload/<id>/`.
3. Filenames are shown as links.

### Download

1. When clicked, the object is pulled from S3 and saved to `/temp`.
2. If **client-encrypted**, it’s decrypted using the stored key and IV.
3. The file is streamed to the browser with correct MIME headers.
4. The file is **auto-deleted** after a timeout using a scheduled task.


## Auto-Deletion Logic

When a file is downloaded:

```bash
exec("echo 'rm "$tmpPath"' | at now + 2 minutes");
```

- This uses the Linux `at` scheduler to delete the file after 2 minutes.
- If `atd` is **not installed**, fallback logic will be added in future versions.

### Why Not `cron` or immediate deletion?

- `cron` isn’t precise for file-specific timers.
- Immediate deletion would prevent download if transfer is slow.
- Using `at` allows **per-file self-expiry**, which is secure and flexible.


## Deployment Instructions

1. **Clone this repo**
```bash
git clone https://github.com/Knightcrawlerr/s3-lockbox-demo.git
cd s3-lockbox-demo
```

2. **Update Terraform variables in `terraform.tfvars`**

3. **Run Terraform**
```bash
terraform init
terraform apply
```

## Security Highlights

| Area            | Practice                                  |
|------------------|---------------------------------------------|
| IAM               | EC2 Role with least privileges               |
| S3 Access         | Restricted bucket policy, VPC endpoint only |
| Encryption        | AES-256 (client-side) + SSE-S3 (server-side)|
| Temp File Handling| Proper permissions, auto-cleanup            |
| File Validation   | MIME + extension check                      |

## Deployment

You can deploy this using Terraform:

```bash
cd terraform/
terraform init
terraform apply
```

## Test the Application

1. Access the **Load Balancer DNS** from the output in your browser.
2. Upload a file and retrieve it using the app interface.
3. Check S3 bucket for uploaded file.

The PHP code is zipped and copied to EC2 via provisioners. Or you can SSH in and run it manually.


## Prerequisites

- AWS account with:
  - An S3 bucket (or create via Terraform)
  - An IAM role for EC2 with `s3:GetObject`, `PutObject`, `ListBucket`
- Linux with:
  - Apache2 + PHP 7.4+
  - `openssl`, `php-mbstring`, `php-xml`, `php-curl`, etc.
  - `at` installed (`sudo apt install at`)
- PHP CLI and AWS SDK (`aws.phar` bundled)

## To-Do / Enhancements

- Add HTTPS via ACM + ALB listener rule
- Add WAF rules
- Monitor with CloudWatch & GuardDuty
- Add pre-signed URL support (future)


