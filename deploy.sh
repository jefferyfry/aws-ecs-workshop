#!/bin/bash

# Create task definition
echo '{
  "containerDefinitions": [
    {
      "name": "aws-ecs-workshop",
      "image": "$IMAGE_NAME",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80,
          "protocol": "tcp"
        },
        {
          "containerPort": 443,
          "hostPort": 443,
          "protocol": "tcp"
        }
      ],
      "healthCheck": {
        "retries": 3,
        "command": [
          "CMD-SHELL",
          "curl -f localhost/health || exit 2"
        ],
        "timeout": 5,
        "interval": 5
      }
    }
  ],
  "family": "circuit-breaker",
  "requiresCompatibilities": [
    "FARGATE"
  ],
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "1024"
}' | envsubst > task_definition.json

# Register task definition
aws ecs register-task-definition --cli-input-json file://task_definition.json

# Create the service
aws ecs create-service \
  --service-name aws-ecs-workshop \
  --cluster aws-ecs-workshop \
  --task-definition aws-ecs-workshop \
  --desired-count 5 \
  --deployment-controller type=ECS \
  --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100,deploymentCircuitBreaker={enable=true,rollback=true}"

