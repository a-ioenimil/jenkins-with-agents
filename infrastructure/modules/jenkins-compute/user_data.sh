#!/bin/bash

set -e

wait_for_internet() {
  echo "Waiting for internet connectivity..."
  until nc -z -v -w5 google.com 443 &> /dev/null; do
    echo "Network is unreachable. Retrying in 5 seconds..."
    sleep 5
  done
  echo "Internet connection established!"
}

wait_for_internet

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y debconf-utils unattended-upgrades fail2ban curl unzip
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades

curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install


docker volume create jenkins_home
docker run -d \
  --name jenkins \
  --restart always \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts-jdk17

echo "Waiting for Jenkins to generate admin password..."
while ! docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword; do
  sleep 2
done

echo "---------------------------------------------------"
echo "Jenkins Initial Admin Password:"
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
echo -e "\n---------------------------------------------------"

echo "Jenkins setup complete."