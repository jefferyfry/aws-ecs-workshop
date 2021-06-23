#!/bin/bash
aws --version

which aws

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

unzip awscliv2.zip

ls -l /usr/local/bin/aws

sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
    
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
  "executionRoleArn": "arn:aws:iam::096302395721:role/ecsTaskExecutionRole",
  "family": "aws-ecs-workshop",
  "requiresCompatibilities": [
    "FARGATE"
  ],
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "1024"
}' | envsubst > task_definition.json

# Register task definition
aws ecs register-task-definition --cli-input-json file://task_definition.json

VPC_ID=$(aws ec2 describe-vpcs --filter Name=tag:Name,Values=aws-ecs-workshop --query Vpcs[].VpcId --output text)
PUBLIC_SUBNET=$(aws ec2 describe-subnets --filter Name=tag:Name,Values=aws-ecs-workshop-public-subnet --query Subnets[].SubnetId --output text)
SEC_GROUP=$(aws ec2 describe-security-groups --filters Name=group-name,Values=default Name=vpc-id,Values=$VPC_ID --query SecurityGroups[].GroupId --output text)

echo "VPC ID is '$VPC_ID'"
echo "Public Subnet is '$PUBLIC_SUBNET'"
echo "Security Group is '$SEC_GROUP'"

# Create the service
aws ecs create-service \
  --service-name aws-ecs-workshop \
  --cluster aws-ecs-workshop \
  --task-definition aws-ecs-workshop \
  --desired-count 5 \
  --deployment-controller type=ECS \
  --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},maximumPercent=200,minimumHealthyPercent=100" \
  --network-configuration "awsvpcConfiguration={subnets=[$PUBLIC_SUBNET],securityGroups=[$SEC_GROUP],assignPublicIp=ENABLED}" \
  --launch-type FARGATE \
  --platform-version 1.4.0

