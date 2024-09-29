#!/bin/bash

# Update the stack name
STACK_NAME="jenkins-efs-ecs-1"
# Update to your desired AWS region
AWS_REGION="us-east-1"

# Set or update the repository name
REPOSITORY_NAME="jenkins"

# Set your AWS profile
AWS_PROFILE="roee"

# Set the image tag
IMAGE_TAG="latest"

# Get the AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --region $AWS_REGION --profile $AWS_PROFILE)

# Create the ECR repository if it doesn't exist
if ! aws ecr describe-repositories --repository-names "${REPOSITORY_NAME}" --region $AWS_REGION --profile $AWS_PROFILE > /dev/null 2>&1; then
    aws ecr create-repository --repository-name "${REPOSITORY_NAME}" --region $AWS_REGION --profile $AWS_PROFILE > /dev/null
fi

# Build the Docker image
docker build -t "${REPOSITORY_NAME}:${IMAGE_TAG}" .

# Get the ECR login command and log in to ECR
aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Tag and push the image to ECR
docker tag "${REPOSITORY_NAME}:${IMAGE_TAG}" "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}:${IMAGE_TAG}"
docker push "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}:${IMAGE_TAG}"

# Export the image URI as an environment variable
IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}:${IMAGE_TAG}"

# Create or update the CloudFormation stack
aws cloudformation update-stack \
  --stack-name "${STACK_NAME}" \
  --template-body file://main.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=ImageURL,ParameterValue="${IMAGE_URI}" \
  --profile "${AWS_PROFILE}" \
  --region "${AWS_REGION}"