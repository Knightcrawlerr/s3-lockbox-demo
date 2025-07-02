#!/bin/bash

# Enable full logging for debug
exec > >(tee /var/log/user_data.log|logger -t user_data -s 2>/dev/console) 2>&1

# Wait for network to be ready (especially important in EC2 ASG)
sleep 30

# Retry apt-get update until success
RETRIES=5
until sudo apt-get update -y; do
  ((RETRIES--))
  echo "Retrying apt-get update... ($RETRIES left)"
  sleep 10
  [ $RETRIES -eq 0 ] && echo "apt-get update failed!" && exit 1
done

# Install packages
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unzip apache2 php php-cli php-xml php-mbstring php-curl php-zip git

# Start and enable apache
sudo systemctl enable apache2
sudo systemctl start apache2

# Deploy app
git clone https://github.com/Knightcrawlerr/s3-lockbox-demo.git /tmp/demo/
sudo mv /tmp/demo/php-app/* /var/www/html/

# Install AWS SDK
sudo curl -L -o /var/www/html/aws.phar 'https://docs.aws.amazon.com/aws-sdk-php/v3/download/aws.phar'

# Setup temp dir
sudo mkdir -p /var/www/html/temp
sudo chown -R www-data:www-data /var/www/html/temp
sudo chmod 750 /var/www/html/temp
