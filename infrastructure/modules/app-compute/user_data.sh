#!/bin/bash
set -x  # Log every command for debugging (visible in /var/log/cloud-init-output.log)

# 1. Update packages (non-fatal — stale repo metadata shouldn't block the rest)
yum update -y || true

# 2. Install Docker
yum install docker -y
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# 3. Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
cd /tmp && unzip -o awscliv2.zip
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# 4. Install git
yum install git -y

# 5. Log completion
echo "App host ready at $(date)" >> /var/log/app-host-init.log

