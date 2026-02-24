pipeline {
    agent {
        label 'spot-agents'
    }

    environment {
        AWS_REGION = 'eu-west-1'
        ECR_REGISTRY = '867344428625.dkr.ecr.eu-west-1.amazonaws.com'
        ECR_REPOSITORY = 'whoami-service-dev'
        IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPOSITORY}:${BUILD_NUMBER}"
        LATEST_IMAGE = "${ECR_REGISTRY}/${ECR_REPOSITORY}:latest"
        APP_HOST_NAME_TAG = 'whoami-service-dev-app-host'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install & Test') {
            steps {
                dir('backend') {
                    sh '''
                    # Install curl on-the-fly to bypass the user_data.sh race condition
                    apt-get update && apt-get install -y curl
                    
                    # Download and install uv to the jenkins user's home directory
                    curl -LsSf https://astral.sh/uv/install.sh | sh
                    
                    # Add uv to the current shell's PATH
                    export PATH="$USERPROFILE/.local/bin:$PATH"
                    export PATH="/home/jenkins/.local/bin:$PATH"
                    export PATH="/root/.local/bin:$PATH"
                    
                    uv sync
                    uv run pytest --cov=src tests/
                    '''
                }
            }
        }

        stage('Docker Build') {
            steps {
                dir('backend') {
                    sh "docker build -t ${IMAGE_NAME} -t ${LATEST_IMAGE} ."
                }
            }
        }

        stage('Push Image to ECR') {
            steps {
                // The IAM Role on the Jenkins agent handles permissions, we just need to authenticate docker
                sh '''
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                docker push ${IMAGE_NAME}
                docker push ${LATEST_IMAGE}
                '''
            }
        }

        stage('Deploy to App Host') {
            steps {
                script {
                    // Look up the private IP of the App Host using the AWS CLI and tags
                    env.APP_HOST_IP = sh(
                        script: """
                        aws ec2 describe-instances \\
                            --region ${AWS_REGION} \\
                            --filters "Name=tag:Name,Values=${APP_HOST_NAME_TAG}" "Name=instance-state-name,Values=running" \\
                            --query "Reservations[0].Instances[0].PrivateIpAddress" \\
                            --output text
                        """,
                        returnStdout: true
                    ).trim()

                    echo "Found App Host IP: ${env.APP_HOST_IP}"

                    if (env.APP_HOST_IP == 'None' || env.APP_HOST_IP == '') {
                        error("Could not find a running EC2 instance with tag Name=${APP_HOST_NAME_TAG}")
                    }
                }

                // Deploy via SSH
                // NOTE: You must create a Jenkins Credential of type "SSH Username with private key"
                // with ID 'app-host-ssh-key', using the user 'ec2-user' and the private key of 'whoami-service-dev-key'.
                sshagent(['app-host-ssh-key']) {
                    // Transfer the deploy script from ci-scripts
                    sh "scp -o StrictHostKeyChecking=no ci-scripts/deploy.sh ec2-user@${APP_HOST_IP}:/home/ec2-user/deploy.sh"
                    
                    // Execute the deployment commands on the remote server
                    sh """
                    ssh -o StrictHostKeyChecking=no ec2-user@${APP_HOST_IP} 'chmod +x deploy.sh && bash /home/ec2-user/deploy.sh "${ECR_REGISTRY}" "${AWS_REGION}" "${LATEST_IMAGE}"'
                    """
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
