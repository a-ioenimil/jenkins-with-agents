#!/bin/bash
set -euo pipefail

# 1. Update packages
yum update -y

# 2. Install Docker
yum install docker -y
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# 3. Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# 4. Install git (optional)
yum install git -y

# 5. Log completion
echo "App host ready" >> /var/log/app-host-init.log
