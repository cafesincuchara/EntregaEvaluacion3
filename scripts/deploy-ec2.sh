#!/bin/bash
set -euo pipefail

EC2_HOST=$1
IMAGE_URI=905418035297.dkr.ecr.us-east-1.amazonaws.com/productosapi:latest

echo "Deploying ProductosAPI to EC2: $EC2_HOST"

ssh -o StrictHostKeyChecking=no ec2-user@$EC2_HOST << EOF
    aws ecr get-login-password --region us-east-1 | \
        docker login --username AWS --password-stdin 905418035297.dkr.ecr.us-east-1.amazonaws.com
    docker pull $IMAGE_URI
    docker stop productosapi || true
    docker rm productosapi || true
    docker run -d -p 8080:8080 \
        --name productosapi \
        --log-driver awslogs \
        --log-opt awslogs-group=/productosapi/microservice \
        --log-opt awslogs-region=us-east-1 \
        --log-opt awslogs-stream-prefix=ec2-productosapi \
        -e SERVER_PORT=8080 \
        -e AWS_REGION=us-east-1 \
        $IMAGE_URI
    docker system prune -f
EOF

echo "Deploy complete. Verifying..."
sleep 5
curl -sf http://$EC2_HOST:8080/actuator/health && echo "Health check passed" || echo "Warning: health check failed"
