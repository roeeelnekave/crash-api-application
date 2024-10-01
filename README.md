# How to deploy this project using CloudFormation

## Prerequisites

1. AWS Account
2. Basic Understanding of AWS services (VPC, EFS, ECS, IAM)
3. Docker and Docker Compose
4. Basic understanding of the CloudFormation template
5. AWS CLI

## STEPS

# Directory

```bash
mkdir -p ./jenkins
```



- **We need a Dockerfile to customize our Jenkins image. Create a Dockerfile:**
- Create a folder for your project and inside that folder create a file named `./jenkins/Dockerfile` and paste the following into the Dockerfile:

```Dockerfile
FROM amazonlinux:2023
RUN yum install -y \
    python3 \
    python3-pip \
    git \
    zip \
    unzip \
    tar \
    gzip \
    wget \
    jq \
    openssh-server \
    openssh-clients \
    which \
    findutils \
    python3-pip && \
    python3 -m pip install awscli && \
    python3 -m pip install boto3 && \
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo && \
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key && \
    yum upgrade -y && \
    yum install -y fontconfig && \
    dnf install java-17-amazon-corretto -y && \
    yum install -y jenkins && \
    python3 -m pip install ansible && \
    yum clean all
EXPOSE 8080
CMD ["java", "-jar", "/usr/share/java/jenkins.war"]
```

- **Create a CloudFormation file for deploying our infrastructure:**
- Create a file named `./jenkins/main.yaml` and paste the following into the YAML template one by one:

   ```yaml
   AWSTemplateFormatVersion: '2010-09-09'
   Description: 'CloudFormation template for VPC with 3 public and 3 private subnets'
   ```
- Create a Parameter for Image URL of jenkins image
```yaml
Parameters:
  ImageURL:
    Type: String
    Description: 'Image URL for the ECR repo'
    Default: 'image-uri'
```
- We then create a VPC in the `Resources` section:

   ```yaml
   Resources:
       VPC:
           Type: AWS::EC2::VPC
           Properties:
               CidrBlock: 10.0.0.0/16
               EnableDnsHostnames: true
               EnableDnsSupport: true
               InstanceTenancy: default
               Tags:
                   - Key: Name
                     Value: project-vpc
   ```

- We then create an Internet Gateway and Internet Gateway attachment:

   ```yaml
       InternetGateway:
           Type: AWS::EC2::InternetGateway
       InternetGatewayAttachment:
           Type: AWS::EC2::VPCGatewayAttachment
           Properties:
               VpcId: !Ref VPC
               InternetGatewayId: !Ref InternetGateway
   ```

- We create 3 Public Subnets and 3 Private Subnets for the VPC for EFS and ECS to be available in different AZs:

   ```yaml
       PublicSubnet1:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 0, !GetAZs '' ]
               CidrBlock: 10.0.1.0/24
               MapPublicIpOnLaunch: true
               Tags:
                   - Key: Name
                     Value: project-subnet-public1-us-east-1a
       PublicSubnet2:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 1, !GetAZs '' ]
               CidrBlock: 10.0.2.0/24
               MapPublicIpOnLaunch: true
               Tags:
                   - Key: Name
                     Value: project-subnet-public2-us-east-1b
       PublicSubnet3:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 2, !GetAZs '' ]
               CidrBlock: 10.0.3.0/24
               MapPublicIpOnLaunch: true
               Tags:
                   - Key: Name
                     Value: project-subnet-public3-us-east-1c
       PrivateSubnet1:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 0, !GetAZs '' ]
               CidrBlock: 10.0.4.0/24
               MapPublicIpOnLaunch: false
               Tags:
                   - Key: Name
                     Value: project-subnet-private1-us-east-1a
       PrivateSubnet2:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 1, !GetAZs '' ]
               CidrBlock: 10.0.5.0/24
               MapPublicIpOnLaunch: false
               Tags:
                   - Key: Name
                     Value: project-subnet-private2-us-east-1b
       PrivateSubnet3:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 2, !GetAZs '' ]
               CidrBlock: 10.0.6.0/24
               MapPublicIpOnLaunch: false
               Tags:
                   - Key: Name
                     Value: project-subnet-private3-us-east-1c
   ```

- We are creating a Public Route Table and its association for the Public Subnet:

   ```yaml
       PublicRouteTable:
           Type: AWS::EC2::RouteTable
           Properties:
               VpcId: !Ref VPC
               Tags:
                   - Key: Name
                     Value: project-rtb-public
       DefaultPublicRoute:
           Type: AWS::EC2::Route
           DependsOn: InternetGatewayAttachment
           Properties:
               RouteTableId: !Ref PublicRouteTable
               DestinationCidrBlock: 0.0.0.0/0
               GatewayId: !Ref InternetGateway
       PublicSubnet1RouteTableAssociation:
           Type: AWS::EC2::SubnetRouteTableAssociation
           Properties:
               RouteTableId: !Ref PublicRouteTable
               SubnetId: !Ref PublicSubnet1
       PublicSubnet2RouteTableAssociation:
           Type: AWS::EC2::SubnetRouteTableAssociation
           Properties:
               RouteTableId: !Ref PublicRouteTable
               SubnetId: !Ref PublicSubnet2
       PublicSubnet3RouteTableAssociation:
           Type: AWS::EC2::SubnetRouteTableAssociation
           Properties:
               RouteTableId: !Ref PublicRouteTable
               SubnetId: !Ref PublicSubnet3
   ```

- We create a NAT Gateway for the EIP and its association for the public subnet and Internet Gateway:

   ```yaml
       NATGateway1:
           Type: AWS::EC2::NatGateway
           Properties:
               AllocationId: !GetAtt NATGateway1EIP.AllocationId
               SubnetId: !Ref PublicSubnet1
       NATGateway1EIP:
           Type: AWS::EC2::EIP
           DependsOn: InternetGatewayAttachment
           Properties:
               Domain: vpc
   ```

- Now we create a NAT Gateway and its association for the Private Subnet:

   ```yaml
       PrivateRouteTable1:
           Type: AWS::EC2::RouteTable
           Properties:
               VpcId: !Ref VPC
               Tags:
                   - Key: Name
                     Value: project-rtb-private1-us-east-1a
       DefaultPrivateRoute1:
           Type: AWS::EC2::Route
           Properties:
               RouteTableId: !Ref PrivateRouteTable1
               DestinationCidrBlock: 0.0.0.0/0
               NatGatewayId: !Ref NATGateway1
       PrivateSubnet1RouteTableAssociation:
           Type: AWS::EC2::SubnetRouteTableAssociation
           Properties:
               RouteTableId: !Ref PrivateRouteTable1
               SubnetId: !Ref PrivateSubnet1
   ```

   (Repeat similar blocks for PrivateRouteTable2 and PrivateRouteTable3)

- We will be creating the ECS and EFS security group and associate it with the VPC that we have just created. We will be opening port `8080` on the ECS security group for Jenkins and `2049` for the ECS Security group for the NFS file system of EFS, allowing `ALL` traffic in outbound:

   ```yaml
       ECSSecurityGroup:
           Type: AWS::EC2::SecurityGroup
           Properties:
               GroupDescription: "ECS Security Group"
               VpcId: !Ref VPC
               SecurityGroupIngress:
                   - IpProtocol: tcp
                     FromPort: 8080
                     ToPort: 8080
                     CidrIp: 0.0.0.0/0
               SecurityGroupEgress:
                   - IpProtocol: "-1"
                     CidrIp: 0.0.0.0/0
       EFSSecurityGroup:
           Type: AWS::EC2::SecurityGroup
           Properties:
               GroupDescription: "EFS Security Group"
               VpcId: !Ref VPC
               SecurityGroupIngress:
                   - IpProtocol: tcp
                     FromPort: 2049
                     ToPort: 2049
                     SourceSecurityGroupId: !Ref ECSSecurityGroup
               SecurityGroupEgress:
                   - IpProtocol: "-1"
                     CidrIp: 0.0.0.0/0
   ```
- We will be creating  IAM policies and role for the ecs to execute  and efs mount 
```yaml

  # Policy for ECS Task
  ECSTaskPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: ecstaskpolicy
      PolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Action:
              - ecr:GetAuthorizationToken
              - ecr:BatchCheckLayerAvailability
              - ecr:GetDownloadUrlForLayer
              - ecr:BatchGetImage
              - logs:CreateLogStream
              - logs:PutLogEvents
            Resource: "*"
      Roles:
        - !Ref ECSEFSmountTaskRole

  # Policy for EFS Mount
  EFSMountPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: efsmountpolicy
      PolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Sid: AllowDescribe
            Effect: Allow
            Action:
              - elasticfilesystem:DescribeAccessPoints
              - elasticfilesystem:DescribeFileSystems
              - elasticfilesystem:DescribeMountTargets
              - ec2:DescribeAvailabilityZones
            Resource: "*"
          - Sid: AllowCreateAccessPoint
            Effect: Allow
            Action:
              - elasticfilesystem:CreateAccessPoint
            Resource: "*"
            Condition:
              Null:
                aws:RequestTag/efs.csi.aws.com/cluster: false
              ForAllValues:StringEquals:
                aws:TagKeys: efs.csi.aws.com/cluster
          - Sid: AllowTagNewAccessPoints
            Effect: Allow
            Action:
              - elasticfilesystem:TagResource
            Resource: "*"
            Condition:
              StringEquals:
                elasticfilesystem:CreateAction: CreateAccessPoint
              Null:
                aws:RequestTag/efs.csi.aws.com/cluster: false
              ForAllValues:StringEquals:
                aws:TagKeys: efs.csi.aws.com/cluster
          - Sid: AllowDeleteAccessPoint
            Effect: Allow
            Action: elasticfilesystem:DeleteAccessPoint
            Resource: "*"
            Condition:
              Null:
                aws:ResourceTag/efs.csi.aws.com/cluster: false
      Roles:
        - !Ref ECSEFSmountTaskRole

  # IAM Role for ECS Tasks
  ECSEFSmountTaskRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: ECSEFSmountTaskRole
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Principal:
              Service: ecs-tasks.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: ECSTaskPolicy
          PolicyDocument:
            Version: "2012-10-17"
            Statement:
              - Effect: Allow
                Action:
                  - ecr:GetAuthorizationToken
                  - ecr:BatchCheckLayerAvailability
                  - ecr:GetDownloadUrlForLayer
                  - ecr:BatchGetImage
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: "*" 
```
- We will be creating the EFS file system:

   ```yaml
       EFSSystem:
           Type: AWS::EFS::FileSystem
           Properties:
               Encrypted: true
               FileSystemTags:
                   - Key: Name
                     Value: JenkinsEFS
   ```

- We need to mount the target for the EFS. For that, we will be using the public subnets `1, 2, 3` that we have just created:

   ```yaml
       JenkinsHomeVolume1:
           Type: AWS::EFS::MountTarget
           Properties:
               FileSystemId: !Ref EFSSystem
               SubnetId: !Ref PublicSubnet1
               SecurityGroups:
                   - !Ref EFSSecurityGroup
       JenkinsHomeVolume2:
           Type: AWS::EFS::MountTarget
           Properties:
               FileSystemId: !Ref EFSSystem
               SubnetId: !Ref PublicSubnet2
               SecurityGroups:
                   - !Ref EFSSecurityGroup
       JenkinsHomeVolume3:
           Type: AWS::EFS::MountTarget
           Properties:
               FileSystemId: !Ref EFSSystem
               SubnetId: !Ref PublicSubnet3
               SecurityGroups:
                   - !Ref EFSSecurityGroup
   ```

- We create an ECS cluster for our application:

   ```yaml
       ECSCluster:
           Type: AWS::ECS::Cluster
           Properties:
               ClusterName: JenkinsCluster
               CapacityProviders:
                   - FARGATE
                   - FARGATE_SPOT
               DefaultCapacityProviderStrategy:
                   - CapacityProvider: FARGATE
                     Weight: 1
                   - CapacityProvider: FARGATE_SPOT
                     Weight: 1
               Configuration:
                   ExecuteCommandConfiguration:
                       Logging: DEFAULT
   ```

- Create a Log group to fetch the log stream of EFS:

   ```yaml
       ECSLogGroup:
           Type: AWS::Logs::LogGroup
           Properties:
               LogGroupName: !Sub "/ecs/test-${AWS::StackName}"
               RetentionInDays: 7
      
   ```

- **Now we are creating the ECS task definition. Comment the *CpuArchitecture* if you are using intel or amd chip (64-bit)** 
   ```yaml

  ECSTaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      ExecutionRoleArn: !Ref ECSEFSmountTaskRole
      TaskRoleArn: !Ref ECSEFSmountTaskRole
      NetworkMode: awsvpc
      RequiresCompatibilities:
        - FARGATE
      RuntimePlatform:
        OperatingSystemFamily: LINUX
        CpuArchitecture: ARM64
      Family: my-jenkins-task-00
      Cpu: "1024"
      Memory: "2048"
      ContainerDefinitions:
        - Name: jenkins
          Image: !Ref ImageURL
          Cpu: 1024
          Memory: 2048
          MemoryReservation: 1024
          Essential: true
          PortMappings:
            - ContainerPort: 8080
              Protocol: tcp
          LinuxParameters:
            InitProcessEnabled: true
          MountPoints:
            - SourceVolume: efs-volume
              ContainerPath: /root/.jenkins
          LogConfiguration:
            LogDriver: awslogs
            Options:
              mode: non-blocking
              max-buffer-size: 25m
              awslogs-group: !Ref ECSLogGroup
              awslogs-region: us-east-1
              awslogs-create-group: "true"
              awslogs-stream-prefix: efs-task
      Volumes:
        - Name: efs-volume
          EFSVolumeConfiguration:
            FilesystemId: !Ref EFSSystem
            RootDirectory: /
            TransitEncryption: ENABLED

- Create a ecs service
```yaml
  ECSService:
    Type: AWS::ECS::Service
    Properties:
      Cluster: !Ref ECSCluster  
      TaskDefinition: !Ref ECSTaskDefinition
      LaunchType: FARGATE
      ServiceName: ebs
      SchedulingStrategy: REPLICA
      DesiredCount: 1
      NetworkConfiguration:
        AwsvpcConfiguration:
          AssignPublicIp: ENABLED
          SecurityGroups: 
            - !Ref ECSSecurityGroup
          Subnets:
            - !Ref PublicSubnet1
            - !Ref PublicSubnet2
            - !Ref PublicSubnet3
      PlatformVersion: LATEST
      DeploymentConfiguration:
        MaximumPercent: 200
        MinimumHealthyPercent: 100
        DeploymentCircuitBreaker:
          Enable: true
          Rollback: true
      DeploymentController:
        Type: ECS
      Tags: []
      EnableECSManagedTags: true
  Outputs:
    VPCID:
      Description: The ID of the created VPC
      Value: !Ref VPC

    PublicSubnet1ID:
      Description: The ID of Public Subnet 1
      Value: !Ref PublicSubnet1

    PublicSubnet2ID:
      Description: The ID of Public Subnet 2
      Value: !Ref PublicSubnet2
```
**Create the bash script and update the Repository Name, aws region and stack name if you desire and  `./jenkins/bash-script.sh` required**

```bash
#!/bin/bash

# update the stack name
STACK_NAME="jenkins-efs-ecs-1"
# update to your desired aws region
AWS_REGION="us-east-1"

# Set or update the repository name
REPOSITORY_NAME="jenkins"

# Set the image tag
IMAGE_TAG="latest"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output --region $AWS_REGION)
# Create the ECR repository
aws ecr describe-repositories --repository-names "${REPOSITORY_NAME}" --region $AWS_REGION > /dev/null 2>&1
if [ $? -ne 0 ]
then
    aws ecr create-repository --repository-name "${REPOSITORY_NAME}" --region $AWS_REGION > /dev/null
fi


# Build the Docker image
docker build -t $REPOSITORY_NAME:$IMAGE_TAG .

# Get the ECR login command
LOGIN_COMMAND=$(aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com)
# Push the image to ECR
docker tag $REPOSITORY_NAME:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG
IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}:${IMAGE_TAG}"

aws cloudformation update-stack \
  --stack-name "${STACK_NAME}" \
  --template-body file://main.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=ImageURL,ParameterValue="${IMAGE_URI}" \
  --region "${AWS_REGION}"
```

- Go to the AWS Console Dashboard navigate to Cloudformation and click on `jenkins-ecs-efs` see the creation process after stack creation is complete go to ecs click on service and click on task access jenkins with the public ip:8080
# Deploying a Crash Management API with Ansible and Cloudformation and Automation Using Jenkins ECS with Jenkins Ec2 Agent and monitoring through Grafana, Promethues
### Prerequities

1. Python3 and python-venv
2.  Ansible
3. Docker
4. aws-cli

**Create a Github repository make it public clone to pc and open the project  and To Create directory structure copy and paste the following in your terminal of your project**
```bash
 mkdir -p ./cloudformation
 mkdir -p ./templates
 mkdir -p ./ansible
 mkdir -p ./ansible/roles
 cd ./ansible/roles
 ansible-galaxy init grafana
 ansible-galaxy init prometheus
 ansible-galaxy init crashapi 
```

#### Setup the infrastructure 
**Create an Elastic IP**
1. **Step 1**: Log in to the AWS Management Console
  - Open your web browser and go to AWS Management Console.
  - Enter your AWS credentials to log in.
2. **Step 2**: Navigate to the EC2 Dashboard
  - Once logged in, find the Services menu at the top of the page and click on it.
  - In the search bar, type EC2 and select EC2 under Compute from the dropdown list.
  - You will be directed to the EC2 Dashboard.
3. **Step 3**: Allocate a New Elastic IP
  - In the EC2 Dashboard, look for the Network & Security section in the left-hand sidebar.
  - Click on Elastic IPs.
  - You will see a page that lists all your current Elastic IPs (if any). Click on the **Allocate -Elastic IP** address button at the top-right corner of the page.
4. **Step 4**: Leave everything to default click on **Allocate**.
5. **Step 5**: Click the ip you have just created copy the ip address and allocation id the allocation starts with `eipalloc-XXXXXXXXXXXX`

#### Repeat the process for promethues and crash api server to create elastic ip

- create a `cloudformation` folder in your root directory of your project  `mkdir cloudformation` inside cloudformation folder.
- To create a `main.yaml` inside the cloudformation `touch ./cloudformation/main.yaml`
- Inside the main.yaml paste the following
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: AWS EC2 Backup Policy for Production Environment

Parameters:
  VPCID:
    Type: AWS::EC2::VPC::Id
    Description: The ID of the VPC where resources will be created
    Default: vpc-056492ac3ce55afbc

  PublicSubnet1:
    Type: AWS::EC2::Subnet::Id
    Description: The ID of the first public subnet for deploying resources
    Default: subnet-0bf4035d161401304

  PublicSubnet2:
    Type: AWS::EC2::Subnet::Id
    Description: The ID of the second public subnet for deploying resources
    Default: subnet-0c51f5611778a305e

  GrafanaEIPAllocationId:
    Type: String
    Description: Allocation ID for Grafana's Elastic IP
    Default: eipalloc-0b5062fd237b05d1b

  CrashAppEIPAllocationId:
    Type: String
    Description: Allocation ID for CrashApp's Elastic IP
    Default: eipalloc-06814b746932fa448
```

- To create the security group and open the required port for grafana promethues and application paste the following in `main.yaml` don't forget to replace the vpc id in `VpcId`
```yaml
Resources:
  GrafanaSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow HTTP, HTTPS, and SSH to Grafana host
      VpcId: !Ref VPCID
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
      SecurityGroupEgress:
        - IpProtocol: "-1"
          CidrIp: 0.0.0.0/0

  CrashAppSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow SSH to CrashApp host
      VpcId: !Ref VPCID
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
      SecurityGroupEgress:
        - IpProtocol: "-1"
          CidrIp: 0.0.0.0/0

  EFSSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow NFS traffic only from Grafana and CrashApp EC2 instances
      VpcId: !Ref VPCID
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 2049
          ToPort: 2049
          SourceSecurityGroupId: !Ref GrafanaSecurityGroup
        - IpProtocol: tcp
          FromPort: 2049
          ToPort: 2049
          SourceSecurityGroupId: !Ref CrashAppSecurityGroup
```

- To create the ec2 instances for grafana, promethues and flask app  paste the following in `main.yaml` don't forget to replace the elastic ip allocation id in `AllocationId` and replace with the public subnet id that you have in your vpc

```yaml

  EfsFileSystem:
    Type: AWS::EFS::FileSystem
    Properties:
      PerformanceMode: generalPurpose
      Encrypted: true

  EfsMountTarget1:
    Type: AWS::EFS::MountTarget
    Properties:
      FileSystemId: !Ref EfsFileSystem
      SubnetId: !Ref PublicSubnet1
      SecurityGroups:
        - !Ref EFSSecurityGroup

  EfsMountTarget2:
    Type: AWS::EFS::MountTarget
    Properties:
      FileSystemId: !Ref EfsFileSystem
      SubnetId: !Ref PublicSubnet2
      SecurityGroups:
        - !Ref EFSSecurityGroup

  GrafanaInstance:
    Type: AWS::EC2::Instance
    DependsOn: EfsMountTarget1
    Properties:
      InstanceType: t3.medium
      ImageId: ami-0e86e20dae9224db8
      KeyName: TestKey
      BlockDeviceMappings:
        - DeviceName: /dev/sda1
          Ebs:
            VolumeSize: 20
            VolumeType: gp2
      NetworkInterfaces:
        - AssociatePublicIpAddress: 'true'
          DeviceIndex: '0'
          SubnetId: !Ref PublicSubnet1
          GroupSet:
            - !Ref GrafanaSecurityGroup
            - !Ref EFSSecurityGroup
      UserData:
        Fn::Base64: !Sub
          - |
            #!/bin/bash
            exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
            sudo apt-get update
            sudo apt-get install -y nfs-common
            sudo mkdir -p /mnt/efs
            
            echo "Waiting for EFS to become available..."
            while ! sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${EFSMountTargetIP}:/ /mnt/efs; do
              sleep 10
              echo "Retrying EFS mount..."
            done
            echo "${EFSMountTargetIP}:/ /mnt/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" | sudo tee -a /etc/fstab
            echo "EFS mount completed."
          - EFSMountTargetIP: !GetAtt EfsMountTarget1.IpAddress
      Tags:
        - Key: Name
          Value: GrafanaServer

  CrashAppServer:
    Type: AWS::EC2::Instance
    DependsOn: EfsMountTarget2
    Properties:
      InstanceType: t3.micro
      ImageId: ami-0e86e20dae9224db8
      KeyName: TestKey
      BlockDeviceMappings:
        - DeviceName: /dev/sda1
          Ebs:
            VolumeSize: 20
            VolumeType: gp3
      NetworkInterfaces:
        - AssociatePublicIpAddress: 'true'
          DeviceIndex: '0'
          SubnetId: !Ref PublicSubnet2
          GroupSet:
            - !Ref CrashAppSecurityGroup
            - !Ref EFSSecurityGroup
      UserData:
        Fn::Base64: !Sub
          - |
            #!/bin/bash
            exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
            sudo apt-get update
            sudo apt-get install -y nfs-common
            sudo mkdir -p /mnt/efs
            
            echo "Waiting for EFS to become available..."
            while ! sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${EFSMountTargetIP}:/ /mnt/efs; do
              sleep 10
              echo "Retrying EFS mount..."
            done
            echo "${EFSMountTargetIP}:/ /mnt/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" | sudo tee -a /etc/fstab
            echo "EFS mount completed."
          - EFSMountTargetIP: !GetAtt EfsMountTarget2.IpAddress
      Tags:
        - Key: Name
          Value: CrashAppServer

  EIPAssociationGrafana:
    Type: 'AWS::EC2::EIPAssociation'
    Properties:
      InstanceId: !Ref GrafanaInstance
      AllocationId: !Ref GrafanaEIPAllocationId

  EIPAssociationCrashApp:
    Type: 'AWS::EC2::EIPAssociation'
    Properties:
      InstanceId: !Ref CrashAppServer
      AllocationId: !Ref CrashAppEIPAllocationId

Outputs:
  EFSFileSystemId:
    Description: The ID of the EFS file system
    Value: !Ref EfsFileSystem
  

  EFSMountTarget1IP:
    Description: IP Address of EFS Mount Target 1
    Value: !GetAtt EfsMountTarget1.IpAddress

  EFSMountTarget2IP:
    Description: IP Address of EFS Mount Target 2
    Value: !GetAtt EfsMountTarget2.IpAddress

  CrashAppPublicIP:
    Description: Public IP of the CrashApp instance 
    Value: !GetAtt CrashAppServer.PublicIp

  GrafanaPublicIP:
    Description: Public IP of the Grafana instance
    Value: !GetAtt GrafanaInstance.PublicIp
              
```

- **Now we create the individual configuration to setup the server configuration using ansible and we will use ansible roles**

    - Inside your `ansible` create a `ansible.cfg` file `touch ./ansible/ansible.cfg` inside we are disablling the `host_key_checking`
      ```conf
       [defaults]
       host_key_checking = False
      ```    
    - Now we create a `inventory` inside `ansible` folder `touch ./ansible/inventory` we are creating the `ansible_user` in inventory file to serve the server dynamically, change the ip addresses for respective server this will be our `elastic ip` 
    ```yaml
    [grafana]
    100.29.106.209 ansible_user=ubuntu
    [prometheus]
    44.203.140.254 ansible_user=ubuntu 
    [crashapi]
    44.203.140.254 ansible_user=ubuntu
    ```
    - Create `main.yaml` inside `ansible` folder `touch ./ansible/main.yaml`  we are deploying multiple host for `grafana`, `promethues`, `crashapi` paste to following inside `./ansible/main.yaml` 
```yaml
---
- hosts: grafana
  become: true
  roles:
    - role: grafana
    - role: prometheus



- hosts: crashapi
  become: true
 
  tasks:
    - name: Install CrashAPI
      include_role:
        name: crashapi
```

**1.Paste the following to configure app, node_exporter and nginx in `./ansible/roles/crashapi/tasks/main.yml`**



```yaml
---
- name: Installing the flask app and creating the systemd service
  import_tasks: install-app.yml

- name: Installing the node exporter and creating the systemd service
  import_tasks: node_exporter.yml

- name: Install nginx and configure ssl
  import_tasks: nginx.yml
```

**2. Create a file  `touch ./ansible/roles/crashapi/tasks/install-app.yml` and Paste the following to configure app in `./ansible/roles/crashapi/tasks/install-app.yml`** in Clone github repository replace with your github repo url


```yaml
- name: Update package lists (on Debian/Ubuntu)
  apt:
    update_cache: yes

- name: Install Python3, pip, and venv
  apt:
    name: "{{ item }}"
    state: latest
    update_cache: yes
  loop: "{{ packages }}"

- name: Manually create the initial virtualenv
  command: python3 -m venv "{{ venv_dir }}"
  args:
    creates: "{{ venv_dir }}"

- name: Clone a GitHub repository
  git:
    repo: https://github.com/roeeelnekave/crash-api-application-part-2.git #Replace with your repo url
    dest: "{{ app_dir }}"
    clone: yes
    update: yes

- name: Install requirements inside the virtual environment
  command: "{{ venv_dir }}/bin/pip install -r {{ app_dir }}/requirements.txt"
  become: true

- name: Ensure application directory exists
  file:
    path: "{{ app_dir }}"
    state: directory
    owner: "{{ user }}"
    group: "{{ group }}"

- name: Ensure virtual environment directory exists
  file:
    path: "{{ venv_dir }}"
    state: directory
    owner: "{{ user }}"
    group: "{{ group }}"

- name: Create systemd service file
  template:
    src: crashapi.service.j2
    dest: /etc/systemd/system/{{ service_name }}.service
  become: true

- name: Reload systemd to pick up the new service
  systemd:
    daemon_reload: yes

- name: Start and enable the Flask app service
  systemd:
    name: "{{ service_name }}"
    state: started
    enabled: yes

- name: Check status of the Flask app service
  command: systemctl status {{ service_name }}
  register: service_status
  ignore_errors: yes

- name: Display service status
  debug:
    msg: "{{ service_status.stdout_lines }}"
```


**3. Create a file  `touch ./ansible/roles/crashapi/tasks/node_exporter.yml` and Paste the following to configure node_exporter in `./ansible/roles/crashapi/tasks/node_exporter.yml`**


```yaml
- name: Download Node Exporter binary
  get_url:
    url: https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz
    dest: /tmp/node_exporter-1.0.1.linux-amd64.tar.gz

- name: Create Node Exporter group
  group:
    name: node_exporter
    state: present

- name: Create Node Exporter user
  user:
    name: node_exporter
    group: node_exporter
    shell: /sbin/nologin
    create_home: no

- name: Create Node Exporter directory
  file:
    path: /etc/node_exporter
    state: directory
    owner: node_exporter
    group: node_exporter

- name: Unpack Node Exporter binary
  unarchive:
    src: /tmp/node_exporter-1.0.1.linux-amd64.tar.gz
    dest: /tmp/
    remote_src: yes

- name: Remove the Node Exporter binary if it exists
  file:
    path: /usr/bin/node_exporter
    state: absent

- name: Install Node Exporter binary
  copy:
    src: "/tmp/node_exporter-1.0.1.linux-amd64/node_exporter"
    dest: /usr/bin/node_exporter
    owner: node_exporter
    group: node_exporter
    mode: '0755'
    remote_src: yes
  become: true

- name: Create Node Exporter service file
  template:
    src: nodeexporter.service.j2
    dest: /usr/lib/systemd/system/node_exporter.service
  become: true

- name: Reload systemd
  systemd:
    daemon_reload: yes

- name: Start Node Exporter service
  systemd:
    name: node_exporter
    state: started
    enabled: yes

- name: Clean up
  file:
    path: /tmp/node_exporter-1.0.1.linux-amd64.tar.gz
    state: absent
  when: clean_up is defined and clean_up
```

**4. Create a file  `touch ./ansible/roles/crashapi/tasks/nginx.yml` and Paste the following to configure nginx in `./ansible/roles/crashapi/tasks/nginx.yml`**


```yaml
---
- name: Update the apt package index
  apt:
    update_cache: yes

- name: Install Nginx and certbot
  apt:
    name:
      - nginx
      - certbot
      - python3-certbot-nginx
    state: present

- name: Remove nginx default configuration
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent

- name: Copy Nginx configuration
  template:
    src: app.conf.j2
    dest: /etc/nginx/sites-available/crash-api.conf

- name: Enable Nginx configuration for Crash-api
  file:
    src: /etc/nginx/sites-available/crash-api.conf
    dest: /etc/nginx/sites-enabled/crash-api.conf
    state: link
  become: true

- name: Test Nginx configuration
  command: nginx -t
  become: true

- name: Restart Nginx
  service:
    name: nginx
    state: restarted
  become: true

- name: Obtain SSL certificate
  shell: certbot --nginx -d {{ crashapi_domain_name}} --non-interactive --agree-tos --email {{ email_user }}
  become: true
```

**5. Create a varaiable to load on our files `./ansible/roles/crashapi/vars/main.yml` and paste the following in this file**


```yaml
---
# vars file for crashapi
app_dir: /home/ubuntu/flask-crash-api
venv_dir: /home/ubuntu/flaskenv
gunicorn_config: /home/ubuntu/flask-crash-api/gunicorn.py
service_name: myflaskapp
user: ubuntu
group: ubuntu
packages:
  - python3
  - python3-pip
  - python3-venv
crashapi_domain_name: "crashapi.example.com"
email_user: example@example.com
```

**6. To create a nginx config for app, create the   `touch ./ansible/roles/crashapi/templates/app.conf.j2` and paste the following in `./ansible/roles/crashapi/templates/app.conf.j2`**


```jinja
server {
  listen 80;
  server_name {{ crashapi_domain_name }}; 

  location / {
    proxy_pass http://localhost:5000;  # Forward requests to Flask app
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```
**7. To create a systemd service for Gunicorn, create the   `touch ./ansible/roles/crashapi/templates/crashapi.service.j2` and paste the following in `./ansible/roles/crashapi/templates/crashapi.service.j2`**

```bash
[Unit]
Description=Gunicorn instance to serve myflaskapp
After=network.target

[Service]
User={{ user }}
Group={{ group }}
WorkingDirectory={{ app_dir }}
ExecStart={{ venv_dir }}/bin/gunicorn -c {{ gunicorn_config }} app:app

[Install]
WantedBy=multi-user.target
```
**8. To create a systemd service for Node Exporter, create the   `touch ./ansible/roles/crashapi/templates/nodeexporter.service.j2` and paste the following in `./ansible/roles/crashapi/templates/nodeexporter.service.j2`**


```bash
[Unit]
Description=Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/bin/node_exporter \
  --web.listen-address=:9200

[Install]
WantedBy=multi-user.target
```

### Now let's configure instance for the grafana

1. **to configure grafana paste the following in this file `./ansible/roles/grafana/tasks/main.yml`**



```yaml
---

- name: Update Packages
  apt:
    update_cache: yes
  tags: packages

- name: Install Packages
  apt:
    name: "{{ item }}"
    state: present
  loop: "{{ packages }}"
  tags: packages

- name: Ensure /etc/apt/keyrings/ directory exists
  file:
    path: /etc/apt/keyrings/
    state: directory
    mode: '0755'
  become: true
  tags: create_directory

- name: Download Grafana GPG key
  ansible.builtin.get_url:
    url: https://apt.grafana.com/gpg.key
    dest: /tmp/grafana.gpg.key
  tags: download_gpg_key

- name: Convert Grafana GPG key to binary format
  ansible.builtin.command: |
    gpg --dearmor -o /etc/apt/keyrings/grafana.gpg /tmp/grafana.gpg.key
  become: true
  tags: dearmor_gpg_key

- name: Clean up temporary GPG key file
  ansible.builtin.file:
    path: /tmp/grafana.gpg.key
    state: absent
  tags: cleanup_gpg_key

- name: Add Grafana stable repository
  ansible.builtin.lineinfile:
    path: /etc/apt/sources.list.d/grafana.list
    line: 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main'
    create: yes
  become: true
  tags: add_stable_repo

- name: Add Grafana beta repository (optional)
  ansible.builtin.lineinfile:
    path: /etc/apt/sources.list.d/grafana.list
    line: 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com beta main'
    create: yes
  become: true
  tags: add_beta_repo

- name: Update the list of available packages
  ansible.builtin.apt:
    update_cache: yes
  become: true
  tags: update_package_list

- name: Install grafana
  apt:
    name: "{{ item }}"
    state: present
  loop: "{{ grafana }}"
  tags: grafana

- name: Ensure Grafana server is enabled and started
  ansible.builtin.systemd:
    name: grafana-server
    enabled: yes
    state: started
  become: true
  tags: grafana_server

- name: Check Grafana server status
  ansible.builtin.systemd:
    name: grafana-server
    state: started
  register: grafana_status
  become: true
  tags: check_grafana_status

- name: Display Grafana server status
  ansible.builtin.debug:
    var: grafana_status
  tags: display_grafana_status

- name: Remove default Nginx configuration
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  become: true
  tags: remove_default_nginx_config

- name: Deploy Grafana Nginx configuration
  template:
    src: grafana.conf.j2
    dest: /etc/nginx/sites-available/grafana.conf

- name: Enable Grafana Nginx configuration
  file:
    src: /etc/nginx/sites-available/grafana.conf
    dest: /etc/nginx/sites-enabled/grafana.conf
    state: link
  become: true
  tags: enable_grafana_nginx_config

- name: Test Nginx configuration
  command: nginx -t
  become: true
  tags: test_nginx_config

- name: Restart Nginx
  service:
    name: nginx
    state: restarted
  become: true
  tags: restart_nginx

- name: Obtain SSL certificates with Certbot
  command: certbot --nginx -d {{ grafana_domain_name }} --non-interactive --agree-tos --email {{ user_email }}
  register: certbot_result
  ignore_errors: true
  become: true
```

2. **To set the variables paste the following in `./ansible/roles/grafana/vars/main.yml`**


```yaml
---

packages:
  - apt-transport-https
  - software-properties-common
  - wget
  - nginx
  - certbot
  - python3-certbot-nginx

grafana:
  - grafana
  - grafana-enterprise

grafana_domain_name: "grafana.example.com"
email: "example@example.com"
```

3. **To configure the grafana with nginx create the file `touch ./ansible/roles/grafana/templates/grafana.conf.j2` and paste the following in `./ansible/roles/grafana/templates/grafana.conf.j2`**

```conf
server {
    listen 80;
    server_name {{ grafana_domain_name }};  # Replace with your domain or IP address

    location / {
        proxy_pass http://localhost:3000;  # Forward requests to Grafana
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Optional: Handle WebSocket connections for Grafana Live
    location /api/live/ {
        proxy_pass http://localhost:3000/api/live/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

### Configure the Promethues server with ansible

1.**Paste the following in `./ansible/roles/prometheus/tasks/main.yml`**

```yaml
---
- name: Update system packages
  apt:
    update_cache: yes

- name: Create a system group for Prometheus
  group:
    name: "{{ prometheus_group }}"
    system: yes

- name: Create a system user for Prometheus
  user:
    name: "{{ prometheus_user }}"
    shell: /sbin/nologin
    system: yes
    group: "{{ prometheus_group }}"

- name: Create directories for Prometheus
  file:
    path: "{{ item }}"
    state: directory
    owner: "{{ prometheus_user }}"
    group: "{{ prometheus_group }}"
  loop:
    - "{{ prometheus_config_dir }}"
    - "{{ prometheus_data_dir }}"

- name: Download Prometheus
  get_url:
    url: "https://github.com/prometheus/prometheus/releases/download/v{{ prometheus_version }}/prometheus-{{ prometheus_version }}.linux-amd64.tar.gz"
    dest: /tmp/prometheus.tar.gz

- name: Extract Prometheus
  unarchive:
    src: /tmp/prometheus.tar.gz
    dest: /tmp/
    remote_src: yes

- name: Move Prometheus binaries
  command: mv /tmp/prometheus-{{ prometheus_version }}.linux-amd64/{{ item }} "{{ prometheus_install_dir }}/"
  loop:
    - prometheus
    - promtool

- name: Remove existing console_libraries directory
  file:
    path: "{{ prometheus_config_dir }}/console_libraries"
    state: absent
    
- name: Remove existing console directory
  file:
    path: "{{ prometheus_config_dir }}/consoles"
    state: absent

- name: Remove existing prometheus.yml file
  file:
    path: "{{ prometheus_config_dir }}/prometheus.yml"
    state: absent

- name: Move configuration files
  command: mv /tmp/prometheus-{{ prometheus_version }}.linux-amd64/{{ item }} "{{ prometheus_config_dir }}/"
  loop:
    - prometheus.yml
    - consoles
    - console_libraries


- name: Set ownership for configuration files
  file:
    path: "{{ prometheus_config_dir }}/{{ item }}"
    owner: "{{ prometheus_user }}"
    group: "{{ prometheus_group }}"
    state: directory
  loop:
    - consoles
    - console_libraries

- name: Create Prometheus systemd service file
  template:
    src: prometheus.service.j2
    dest: /etc/systemd/system/prometheus.service
  become: true

- name: Reload systemd
  command: systemctl daemon-reload
  become: true

- name: Enable and start Prometheus service
  systemd:
    name: prometheus
    enabled: yes
    state: started
  become: true 
```
2. **To set default varaibles paste the following in `./ansible/roles/prometheus/defaults/main.yml` don't forget to replace `crash_api_ip` with your application server ip**
```yaml
---
prometheus_version: "2.54.0"
prometheus_user: "prometheus"
prometheus_group: "prometheus"
prometheus_install_dir: "/usr/local/bin"
prometheus_config_dir: "/etc/prometheus"
prometheus_data_dir: "/var/lib/prometheus"
crash_api_ip: "127.0.0.1"
```
3. **To create a services for systemd create a file in  `touch ./ansible/roles/prometheus/templates/promethues.service.j2` and paste the following `./ansible/roles/prometheus/templates/promethues.service.j2`**
```bash
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User={{ prometheus_user }}
Group={{ prometheus_group }}
Type=simple
ExecStart={{ prometheus_install_dir }}/prometheus \
  --config.file {{ prometheus_config_dir }}/prometheus.yml \
  --storage.tsdb.path {{ prometheus_data_dir }} \
  --web.console.templates={{ prometheus_config_dir }}/consoles \
  --web.console.libraries={{ prometheus_config_dir }}/console_libraries

[Install]
WantedBy=multi-user.target

```
4. **To create a promethues configuration create a file in  `touch ./ansible/roles/prometheus/templates/promethues.yml.j2` and paste the following `./ansible/roles/prometheus/templates/promethues.yml.j2`**

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'crash-api'
    static_configs:
      - targets: ['{{ crash_api_ip }}:9100']
```

### Now let's create the python app
1. **Create `./app.py` in root directory of your project and paste the following**
```python
from flask import Flask, request, render_template, jsonify, redirect
import requests

app = Flask(__name__)

# Route for the input form
@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        state_case = request.form['stateCase']
        case_year = request.form['caseYear']
        state = request.form['state']
        return redirect(f'/results?stateCase={state_case}&caseYear={case_year}&state={state}')
    return render_template('index.html')

# Route for displaying results
@app.route('/results')
def results():
    state_case = request.args.get('stateCase')
    case_year = request.args.get('caseYear')
    state = request.args.get('state')
    
    # Call the NHTSA Crash API
    url = f"https://crashviewer.nhtsa.dot.gov/CrashAPI/crashes/GetCaseDetails?stateCase={state_case}&caseYear={case_year}&state={state}&format=json"
    response = requests.get(url)
    
    if response.status_code != 200:
        return render_template('results.html', data={"error": "Failed to retrieve data from the API."})

    data = response.json()  # Assuming the API returns JSON data

    return render_template('results.html', data=data)

# API endpoint for cURL
@app.route('/api/crashdata', methods=['GET'])
def api_crashdata():
    state_case = request.args.get('stateCase')
    case_year = request.args.get('caseYear')
    state = request.args.get('state')
    
    # Call the NHTSA Crash API
    url = f"https://crashviewer.nhtsa.dot.gov/CrashAPI/crashes/GetCaseDetails?stateCase={state_case}&caseYear={case_year}&state={state}&format=json"
    response = requests.get(url)
    
    if response.status_code != 200:
        return jsonify({"error": "Failed to retrieve data from the API."}), response.status_code

    data = response.json()

    return jsonify(data)

if __name__ == '__main__':
    app.run(debug=True)
```
2. **Create `./guniucorn.py` and paste following**:
```python
bind = "0.0.0.0:5000"
workers = 2
```
3. **Create a html to load template `touch ./templates/index.html` and paste the following `./templates/index.html`**

```html
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Crash Data Input</title>
        </head>
        <body>
            <h1>Enter Crash Data Parameters</h1>
            <form method="POST">
                <label for="stateCase">State Case:</label>
                <input type="text" id="stateCase" name="stateCase" required>
                
                <label for="caseYear">Case Year:</label>
                <input type="text" id="caseYear" name="caseYear" required>
                
                <label for="state">State:</label>
                <input type="text" id="state" name="state" required>
                
                <button type="submit">Submit</button>
            </form>
        </body>
        </html>
```
4.  **Create a html to load template `touch ./templates/results.html` and paste the following `./templates/results.html`**
```html
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Crash Data Results</title>
        </head>
        <body>
            <h1>Crash Data Results</h1>
            <pre>{{ data | tojson(indent=2) }}</pre>
            <a href="/">Go Back</a>
        </body>
        </html>
```
5. **Create a `./requirements.txt` file and paste the following**
```bash
blinker==1.8.2
certifi==2024.7.4
charset-normalizer==3.3.2
click==8.1.7
Flask==3.0.3
idna==3.7
itsdangerous==2.2.0
Jinja2==3.1.4
MarkupSafe==2.1.5
requests==2.32.3
urllib3==2.2.2
Werkzeug==3.0.3
gunicorn
```
### Now create a jenkins pipeline script 
1. Create a `./Jenkinsfile` inside the root directory of the project

```groovy
pipeline {
    agent any
    
    parameters {
        string(name: 'grafana_domain_name', defaultValue: 'grafana.example.com', description: 'Grafana domain name')
        string(name: 'crashapi_domain_name', defaultValue: 'api.example.com', description: 'Crash API domain name')
        string(name: 'email_user', defaultValue: 'user@example.com', description: 'Email user')
        string(name: 'ssh_credentials_id', defaultValue: 'your-credential-id', description: 'ID of the SSH private key credential')
    }
    
    stages {
        stage("Deploy Main CloudFormation") {
            steps {
                script {
                    // Set AWS credentials
                    withCredentials([string(credentialsId: 'aws_access_key_id', variable: 'aws_access_key_id'), 
                                     string(credentialsId: 'aws_secret_access_key', variable: 'aws_secret_access_key')]) {
                        sh '''
                            aws configure set aws_access_key_id $aws_access_key_id
                            aws configure set aws_secret_access_key $aws_secret_access_key
                            aws configure set default.region us-east-1
                        '''
                    }

                    // Fetch existing CloudFormation stack outputs
                    def output1 = sh(script: 'aws cloudformation describe-stacks --stack-name jenkins-efs-ecs-1 --query "Stacks[0].Outputs"', returnStdout: true).trim()
                    def jsonOutput1 = readJSON(text: output1)

                    // Extract parameters from the stack outputs
                    def VPCID = jsonOutput1.find { it.OutputKey == 'VPCID' }.OutputValue
                    def PublicSubnet1 = jsonOutput1.find { it.OutputKey == 'PublicSubnet1ID' }.OutputValue
                    def PublicSubnet2 = jsonOutput1.find { it.OutputKey == 'PublicSubnet2ID' }.OutputValue

                    // Run AWS CloudFormation create-stack command
                    def createStack = sh(
                        script: """
                            aws cloudformation create-stack --stack-name grafanaPrometheus --template-body file://cloudformation/main.yaml \
                            --parameters ParameterKey=VPCID,ParameterValue=${VPCID} \
                            ParameterKey=PublicSubnet1,ParameterValue=${PublicSubnet1} \
                            ParameterKey=PublicSubnet2,ParameterValue=${PublicSubnet2}
                        """,
                        returnStatus: true
                    )

                    // Check if CloudFormation stack creation was successful
                    if (createStack == 0) {
                        echo "CloudFormation stack creation started successfully."

                        Wait for the stack creation to complete
                        def waitForStack = sh(
                            script: 'aws cloudformation wait stack-create-complete --stack-name grafanaPrometheus',
                            returnStatus: true
                        )

                        Check if waiting for stack creation was successful
                        if (waitForStack == 0) {
                            echo "CloudFormation stack creation completed successfully."

                            // Retrieve public IPs of EC2 instances from CloudFormation outputs
                            def output = sh(script: 'aws cloudformation describe-stacks --stack-name grafanaPrometheus --query "Stacks[0].Outputs"', returnStdout: true).trim()
                            def jsonOutput = readJSON(text: output)

                            // Extract IPs from outputs
                            def grafanaIp = jsonOutput.find { it.OutputKey == 'GrafanaPublicIP' }.OutputValue
                            def crashApiIp = jsonOutput.find { it.OutputKey == 'CrashAppPublicIP' }.OutputValue

                            // Create Ansible inventory content
                            def inventoryContent = """
[grafana]
${grafanaIp} ansible_user=ubuntu

[crashapi]
${crashApiIp} ansible_user=ubuntu
"""                          
                            // Write inventory to a file
                            writeFile file: 'ansible/inventory', text: inventoryContent

                        } else {
                            error "Failed to wait for CloudFormation stack creation to complete."
                        }
                    } else {
                        error "Failed to create CloudFormation stack."
                    }
                }
            }
        }
        
       stage("Deploy Grafana, Prometheus, and Crash API Server") {
    steps {
        dir('ansible') {
            withCredentials([sshUserPrivateKey(credentialsId: 'TestKey', keyFileVariable: 'TestKey')]) {
                // Display inventory
                script {
                    def output = sh(script: 'aws cloudformation describe-stacks --stack-name grafanaPrometheus --query "Stacks[0].Outputs"', returnStdout: true).trim()
                    def jsonOutput = readJSON(text: output)
                    def crashApiIp = jsonOutput.find { it.OutputKey == 'CrashAppPublicIP' }.OutputValue
                
                sh "cat inventory"
                // Save private key
                sh "echo ${TestKey} > key.pem"
                sh "chmod 400 key.pem"
                sh "cat key.pem"
                // Run Ansible playbook
                sh """
                    ansible-playbook -i inventory --private-key ${TestKey} \
                    --extra-vars 'crash_api_ip=${crashApiIp} grafana_domain_name=${params.grafana_domain_name} efs_id=fs-0952230233c19bafa crashapi_domain_name=${params.crashapi_domain_name} email_user=${params.email_user}' \
                    main.yaml
                """
                }
            }
        }
    }
}
    }
}
```
## Do a git push
```bash
git add .
git commit -m "Adding the required files"
git push
```
### Running the pipeline 




### Steps Jenkins CI 





#### Steps to Create Access Key and Secret Key
1. Sign in to the AWS Management Console:
2. Go to the AWS Management Console at https://aws.amazon.com/console/.
3. Enter your account credentials to log in.
4. Navigate to IAM:
5. In the AWS Management Console, search for "IAM" in the services search bar and select IAM.
6. Select Users:
7. In the IAM dashboard, click on Users in the left navigation pane.
8. Choose the User:
9. Click on the name of the user for whom you want to create access keys. If you need to create a a new user, click on Add user, enter a username, and select Programmatic access.
10. Access Security Credentials:
11. After selecting the user, click on the Security credentials tab.
12. Create Access Key:
    - In the Access keys section, click on Create access key.
    - If the button is disabled, it means the user already has two active access keys, and you will need to delete one before creating a new one.
13. Configure Access Key:
   - You will be directed to a page that provides options for creating the access key. You can optionally add a description to help identify the key later.
14. Click on Create access key.
15. Retrieve Access Key:
   - After the access key is created, you will see the Access key ID and Secret access key.
**Important: This is your only opportunity to view or download the secret access key. Click Show to reveal it or choose to Download .csv file to save it securely.**
16. Secure Your Keys:
    - Store the access key ID and secret access key in a secure location. Do not share these keys publicly or hard-code them into your applications.
17. Complete the Process:
    - After saving your keys, click Done to finish the process.
**Important Notes**
**Access Key ID: This is a public identifier and can be shared.**
**Secret Access Key: This should be kept confidential and secure. If you lose it, you must create a new access key.**
**You can have a maximum of two access keys per IAM user. If you need more, deactivate or delete existing keys.**

## Again in AWS console
1. Navigate to Ec2 Dashboard
2. Click on key pairs.
3. Create a Key pair give it a Name TestKey and Click on Create.
4. Save it Downloads folder
# Go to Jenkins DashBoard
1. Go to manage jenkins -> Credentials -> Under *Stores scoped to Jenkins* click on **System** -> Global credentials (unrestricted) -> Add Credentials
2. On **Kind** select as `SSH username with private key`
3. On **ID** give it a unique name like `TestKey`
4. On **Description** give it a Description like `key agent to deploy grafana, promethues and application in aws`.
5. On **Username** give it the server username in our case it's `ubuntu`
6. On **Private Key** section select `Enter Directly` under key click `Add` and copy the contents of the keypair `TestKey.pem` and paste it there then click on **Create** 

 7. Again Go to manage jenkins -> Credentials -> Under *Stores scoped to Jenkins* click on **System** -> Global credentials (unrestricted) -> Add Credentials 
 8. Kind select `Secret Text`
 9. ID `aws_access_key_id` and on secret paste the value of access key from the aws that you have just created.
 10. Description `access key for  aws` then click on **Create** 
11. Again Go to manage jenkins -> Credentials -> Under *Stores scoped to Jenkins* click on **System** -> Global credentials (unrestricted) -> Add Credentials 
 12. Kind select `Secret Text`
 9. ID `aws_secret_access_key` and on secret paste the value of secret key from the aws that you have just created.
 10. Description `secret key for  aws` then click on **Create** 

**Now lets create a pipeline to deploy our application**

1. Go to Jenkins DashBoard
2. Click on **+ New Item**
3. Give it a name like `server-deployment`
4. Scroll Down to **Pipeline** select `Definition` as **Pipeline script from SCM**.
5. On **SCM** select **Git** on  **Repositories** give your repository url from github.
6. Under **Branches to build** in `Branch Specifier (blank for 'any')` edit that as `main` then Click on **Save**.
7. Click on **Build Now**
