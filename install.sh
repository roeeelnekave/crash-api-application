#!/bin/bash
sudo apt update
sudo apt install awscli -y
sudo apt install python3-pip -y
sudo apt install python3-venv -y
sudo apt install ansible -y

# Prompt for AWS credentials and region
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXX
AWS_REGION=us-east-1


# Configure AWS CLI
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set region "$AWS_REGION"

echo "AWS CLI has been configured successfully."