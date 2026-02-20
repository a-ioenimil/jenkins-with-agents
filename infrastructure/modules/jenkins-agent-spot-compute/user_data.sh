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

# Get Docker socket GID for permission mapping
DOCKER_GID=$(getent group docker | cut -d: -f3)

# Run Jenkins SSH Agent with Docker socket mounted (Docker-outside-of-Docker)
docker run -d \
  --name jenkins-agent \
  --restart=on-failure \
  -p 2222:22 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e "JENKINS_AGENT_SSH_PUBKEY=${ssh_public_key}" \
  jenkins/ssh-agent:latest

# Wait for the container to fully initialize
sleep 5

# Install Docker CLI (static binary) inside the container
docker exec jenkins-agent bash -c "\
  apt-get update && apt-get install -y curl unzip && \
  curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.5.1.tgz -o /tmp/docker.tgz && \
  tar xzf /tmp/docker.tgz --strip-components=1 -C /usr/local/bin docker/docker && \
  rm -f /tmp/docker.tgz && \
  chmod +x /usr/local/bin/docker"

# Grant jenkins user access to the mounted Docker socket
docker exec jenkins-agent bash -c "\
  groupadd -g $DOCKER_GID docker-host 2>/dev/null || true && \
  usermod -aG docker-host jenkins"

# Install AWS CLI v2 inside the container (needed for ECR push/pull)
docker exec jenkins-agent bash -c "\
  curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o '/tmp/awscliv2.zip' && \
  unzip -q /tmp/awscliv2.zip -d /tmp && \
  /tmp/aws/install && \
  rm -rf /tmp/aws /tmp/awscliv2.zip"
