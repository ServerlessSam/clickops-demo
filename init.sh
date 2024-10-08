#!/bin/bash

# Set variables
REGION="eu-west-2"

# Generate unique identifiers to avoid naming conflicts
RANDOM_ID=$RANDOM

VPC_CIDR_BLOCK="10.0.0.0/16"
PUBLIC_SUBNET_CIDR_BLOCKS=("10.0.1.0/24" "10.0.2.0/24")
PRIVATE_SUBNET_CIDR_BLOCKS=("10.0.3.0/24" "10.0.4.0/24")
KEY_PAIR_NAME="my-key-pair-$RANDOM_ID"
EC2_INSTANCE_NAME="MyEC2Instance-$RANDOM_ID"
EC2_INSTANCE_TYPE="t3.micro"
AMI_ID="ami-0b4c7755cdf0d9219"  # Amazon Linux 2 AMI (change as needed)
EC2_ROLE_NAME="EC2Role-$RANDOM_ID"
INSTANCE_PROFILE_NAME="EC2InstanceProfile-$RANDOM_ID"

RDS_DB_INSTANCE_IDENTIFIER="mydbinstance-$RANDOM_ID"
RDS_DB_NAME="mydatabase"
RDS_MASTER_USERNAME="admin"
RDS_MASTER_PASSWORD="Password123!"  # Should comply with RDS password policy
RDS_DB_INSTANCE_CLASS="db.t3.micro"
RDS_ENGINE="mysql"
RDS_ALLOCATED_STORAGE=20

S3_BUCKET_NAME="my-unique-bucket-name-$RANDOM_ID"
DYNAMODB_TABLE_NAME="MyDynamoDBTable-$RANDOM_ID"

LAMBDA_FUNCTION_NAME="MyLambdaFunction-$RANDOM_ID"
LAMBDA_ROLE_NAME="LambdaExecutionRole-$RANDOM_ID"
LAMBDA_HANDLER="lambda_function.lambda_handler"
LAMBDA_RUNTIME="python3.8"  # Change as needed
LAMBDA_ZIP_FILE="lambda_function.zip"  # Path to your Lambda function code

API_NAME="MyAPI-$RANDOM_ID"

echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block $VPC_CIDR_BLOCK \
    --query 'Vpc.VpcId' \
    --output text \
    --region $REGION)

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=MyVPC-$RANDOM_ID --region $REGION

echo "Enabling DNS support and DNS hostnames on the VPC..."
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-support \
    --region $REGION

aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames \
    --region $REGION

echo "Retrieving Availability Zones..."
AZS=($(aws ec2 describe-availability-zones \
    --region $REGION \
    --query 'AvailabilityZones[?State==`available`].ZoneName' \
    --output text))

if [ ${#AZS[@]} -lt 2 ]; then
    echo "Error: Less than 2 Availability Zones available in region $REGION."
    exit 1
fi

echo "Creating public subnets across different Availability Zones..."
PUBLIC_SUBNET_IDS=()
for i in {0..1}; do
    SUBNET_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block ${PUBLIC_SUBNET_CIDR_BLOCKS[$i]} \
        --availability-zone ${AZS[$i]} \
        --query 'Subnet.SubnetId' \
        --output text \
        --region $REGION)
    aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=PublicSubnet-$((i+1))-$RANDOM_ID --region $REGION
    PUBLIC_SUBNET_IDS+=($SUBNET_ID)
done

echo "Creating private subnets across different Availability Zones..."
PRIVATE_SUBNET_IDS=()
for i in {0..1}; do
    SUBNET_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block ${PRIVATE_SUBNET_CIDR_BLOCKS[$i]} \
        --availability-zone ${AZS[$i]} \
        --query 'Subnet.SubnetId' \
        --output text \
        --region $REGION)
    aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=PrivateSubnet-$((i+1))-$RANDOM_ID --region $REGION
    PRIVATE_SUBNET_IDS+=($SUBNET_ID)
done

echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --query 'InternetGateway.InternetGatewayId' \
    --output text \
    --region $REGION)

aws ec2 attach-internet-gateway \
    --vpc-id $VPC_ID \
    --internet-gateway-id $IGW_ID \
    --region $REGION

echo "Creating Route Tables..."
# Public Route Table
PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --query 'RouteTable.RouteTableId' \
    --output text \
    --region $REGION)

aws ec2 create-tags --resources $PUBLIC_ROUTE_TABLE_ID --tags Key=Name,Value=PublicRouteTable-$RANDOM_ID --region $REGION

aws ec2 create-route \
    --route-table-id $PUBLIC_ROUTE_TABLE_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID \
    --region $REGION

# Private Route Table (No outbound route to IGW)
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --query 'RouteTable.RouteTableId' \
    --output text \
    --region $REGION)

aws ec2 create-tags --resources $PRIVATE_ROUTE_TABLE_ID --tags Key=Name,Value=PrivateRouteTable-$RANDOM_ID --region $REGION

echo "Associating subnets with Route Tables..."
# Associate Public Subnets with Public Route Table
for SUBNET_ID in "${PUBLIC_SUBNET_IDS[@]}"; do
    aws ec2 associate-route-table \
        --subnet-id $SUBNET_ID \
        --route-table-id $PUBLIC_ROUTE_TABLE_ID \
        --region $REGION
done

# Associate Private Subnets with Private Route Table
for SUBNET_ID in "${PRIVATE_SUBNET_IDS[@]}"; do
    aws ec2 associate-route-table \
        --subnet-id $SUBNET_ID \
        --route-table-id $PRIVATE_ROUTE_TABLE_ID \
        --region $REGION
done

echo "Enabling Auto-assign Public IP on Public Subnets..."
for SUBNET_ID in "${PUBLIC_SUBNET_IDS[@]}"; do
    aws ec2 modify-subnet-attribute \
        --subnet-id $SUBNET_ID \
        --map-public-ip-on-launch \
        --region $REGION
done

echo "Creating Key Pair..."
aws ec2 create-key-pair \
    --key-name $KEY_PAIR_NAME \
    --query 'KeyMaterial' \
    --output text \
    --region $REGION > $KEY_PAIR_NAME.pem
chmod 400 $KEY_PAIR_NAME.pem

echo "Creating IAM Role for EC2..."
aws iam create-role \
    --role-name $EC2_ROLE_NAME \
    --assume-role-policy-document file://<(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
)

echo "Attaching policies to EC2 IAM Role..."
aws iam attach-role-policy \
    --role-name $EC2_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

echo "Creating Instance Profile..."
aws iam create-instance-profile \
    --instance-profile-name $INSTANCE_PROFILE_NAME

aws iam add-role-to-instance-profile \
    --instance-profile-name $INSTANCE_PROFILE_NAME \
    --role-name $EC2_ROLE_NAME

echo "Waiting for IAM role to propagate..."
sleep 10  # Wait for IAM role to become available

echo "Creating Security Group for EC2..."
EC2_SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name EC2-SG-$RANDOM_ID \
    --description "Security group for EC2 instance" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text \
    --region $REGION)

# Allow SSH access from anywhere (adjust as needed)
aws ec2 authorize-security-group-ingress \
    --group-id $EC2_SECURITY_GROUP_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region $REGION

echo "Launching EC2 Instance..."
EC2_INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $EC2_INSTANCE_TYPE \
    --key-name $KEY_PAIR_NAME \
    --iam-instance-profile Name=$INSTANCE_PROFILE_NAME \
    --security-group-ids $EC2_SECURITY_GROUP_ID \
    --subnet-id ${PUBLIC_SUBNET_IDS[0]} \
    --associate-public-ip-address \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)

aws ec2 create-tags \
    --resources $EC2_INSTANCE_ID \
    --tags Key=Name,Value=$EC2_INSTANCE_NAME \
    --region $REGION

echo "Creating Security Group for RDS..."
RDS_SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name RDS-SG-$RANDOM_ID \
    --description "Security group for RDS instance" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text \
    --region $REGION)

# Allow inbound access to RDS from EC2 Security Group
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SECURITY_GROUP_ID \
    --protocol tcp \
    --port 3306 \
    --source-group $EC2_SECURITY_GROUP_ID \
    --region $REGION

echo "Creating RDS Subnet Group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name mydbsubnetgroup-$RANDOM_ID \
    --db-subnet-group-description "My DB subnet group" \
    --subnet-ids ${PRIVATE_SUBNET_IDS[@]} \
    --region $REGION

echo "Creating RDS Instance in Private Subnets..."
aws rds create-db-instance \
    --db-instance-identifier $RDS_DB_INSTANCE_IDENTIFIER \
    --db-instance-class $RDS_DB_INSTANCE_CLASS \
    --engine $RDS_ENGINE \
    --allocated-storage $RDS_ALLOCATED_STORAGE \
    --master-username $RDS_MASTER_USERNAME \
    --master-user-password $RDS_MASTER_PASSWORD \
    --vpc-security-group-ids $RDS_SECURITY_GROUP_ID \
    --db-subnet-group-name mydbsubnetgroup-$RANDOM_ID \
    --no-publicly-accessible \
    --region $REGION

echo "Creating S3 Bucket..."
aws s3api create-bucket \
    --bucket $S3_BUCKET_NAME \
    --create-bucket-configuration LocationConstraint=$REGION \
    --region $REGION

echo "Creating DynamoDB Table..."
aws dynamodb create-table \
    --table-name $DYNAMODB_TABLE_NAME \
    --attribute-definitions AttributeName=ID,AttributeType=S \
    --key-schema AttributeName=ID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION

echo "Creating IAM Role for Lambda..."
aws iam create-role \
    --role-name $LAMBDA_ROLE_NAME \
    --assume-role-policy-document file://<(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
)

echo "Attaching policies to Lambda IAM Role..."
aws iam attach-role-policy \
    --role-name $LAMBDA_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

echo "Waiting for IAM role to propagate..."
sleep 10  # Wait for IAM role to become available

echo "Creating Lambda Function..."
# Create a simple Lambda function zip file if not exists
if [ ! -f $LAMBDA_ZIP_FILE ]; then
    echo "Creating sample Lambda function code..."
    echo 'def lambda_handler(event, context):
    return {"statusCode": 200, "body": "Hello from Lambda"}' > lambda_function.py
    zip $LAMBDA_ZIP_FILE lambda_function.py
fi

LAMBDA_ROLE_ARN=$(aws iam get-role \
    --role-name $LAMBDA_ROLE_NAME \
    --query 'Role.Arn' \
    --output text \
    --region $REGION)

aws lambda create-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --runtime $LAMBDA_RUNTIME \
    --role $LAMBDA_ROLE_ARN \
    --handler $LAMBDA_HANDLER \
    --zip-file fileb://$LAMBDA_ZIP_FILE \
    --region $REGION

echo "Creating API Gateway..."
API_ID=$(aws apigateway create-rest-api \
    --name $API_NAME \
    --query 'id' \
    --output text \
    --region $REGION)

ROOT_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --query 'items[0].id' \
    --output text \
    --region $REGION)

RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part "{proxy+}" \
    --query 'id' \
    --output text \
    --region $REGION)

aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method ANY \
    --authorization-type "NONE" \
    --region $REGION

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)

LAMBDA_FUNCTION_ARN="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$LAMBDA_FUNCTION_NAME"

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method ANY \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_FUNCTION_ARN/invocations" \
    --region $REGION

echo "Adding permission for API Gateway to invoke Lambda..."
aws lambda add-permission \
    --function-name $LAMBDA_FUNCTION_NAME \
    --statement-id apigateway-test-$RANDOM_ID \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/*/*" \
    --region $REGION

echo "Deploying API..."
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region $REGION

API_INVOKE_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/prod"

echo "Deployment complete."
echo "API Gateway Invoke URL: $API_INVOKE_URL/{proxy+}"