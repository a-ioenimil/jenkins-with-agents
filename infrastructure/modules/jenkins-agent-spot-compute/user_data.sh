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

# Give all users access to the Docker socket
chmod 666 /var/run/docker.sock

# Run Jenkins SSH Agent with Docker socket mounted (Docker-outside-of-Docker)
docker run -d \
  --name jenkins-agent \
  --restart=on-failure \
  -p 2222:22 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e "JENKINS_AGENT_SSH_PUBKEY=${ssh_public_key}" \
  jenkins/ssh-agent:latest

# Wait for the container to fully initialize
sleep 10

# Install Docker CLI and plugins (buildx, compose) via official apt repository
docker exec jenkins-agent bash -c "\
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do apt-get remove -y \$pkg; done && \
  apt-get update && apt-get install -y ca-certificates curl gnupg && \
  install -m 0755 -d /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
  chmod a+r /etc/apt/keyrings/docker.gpg && \
  echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \$(. /etc/os-release && echo \"\$VERSION_CODENAME\") stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  apt-get update && \
  apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin"


# Install AWS CLI v2 inside the container (needed for ECR push/pull)
docker exec jenkins-agent bash -c "\
  curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o '/tmp/awscliv2.zip' && \
  unzip -q /tmp/awscliv2.zip -d /tmp && \
  /tmp/aws/install && \
  rm -rf /tmp/aws /tmp/awscliv2.zip"

echo "Jenkins agent setup complete. SSH on port 2222 with the provided key."
