#!/bin/bash
set -euo pipefail

# Update packages
yum update -y

# Install Java 17 (Corretto)
yum install java-17-amazon-corretto -y

# Install Docker
yum install docker -y
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Install AWS CLI v2
yum install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install git
yum install git -y

# Run Jenkins SSH Agent in Docker
# Creating a dedicated user/group might be better practice, but using default for now
docker run -d \
  --name jenkins-agent \
  -p 2222:22 \
  -e "JENKINS_AGENT_SSH_PUBKEY=${ssh_public_key}" \
  jenkins/ssh-agent:latest
