#!/bin/bash
set -euo pipefail
export PATH=$PATH:/usr/local/bin:/usr/bin

# Read arguments
ECR_REGISTRY=$1
AWS_REGION=$2
IMAGE=$3

echo "Starting Deployment on App Host..."

# 1. Authenticate Docker with AWS ECR
echo "Authenticating with ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

# 2. Pull the latest image
echo "Pulling latest image: ${IMAGE}"
docker pull "${IMAGE}"

# 3. Stop the existing container if running
echo "Stopping existing container..."
docker stop backend-api || true
docker rm backend-api || true

# 4. Start the new container
echo "Starting new container..."
docker run -d \
    --name backend-api \
    --restart unless-stopped \
    -p 80:5000 \
    "${IMAGE}"

# 5. Verify the container is running
echo "Verifying container status..."
sleep 3
if [ "$(docker inspect -f '{{.State.Running}}' backend-api)" = "true" ]; then
    echo "Deployment Successful! Application is running."
else
    echo "Deployment Failed! Container is not running."
    docker logs backend-api
    exit 1
fi

# 6. Clean up old, unused Docker images
echo "Cleaning up..."
docker system prune -af --filter "until=24h"

echo "Deployment finished."
