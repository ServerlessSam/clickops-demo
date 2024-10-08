# Terminate EC2 Instance
aws ec2 terminate-instances --instance-ids $EC2_INSTANCE_ID --region $REGION

# Delete RDS Instance
aws rds delete-db-instance --db-instance-identifier $RDS_DB_INSTANCE_IDENTIFIER --skip-final-snapshot --region $REGION

# Delete S3 Bucket
aws s3 rb s3://$S3_BUCKET_NAME --force --region $REGION

# Delete DynamoDB Table
aws dynamodb delete-table --table-name $DYNAMODB_TABLE_NAME --region $REGION

# Delete Lambda Function
aws lambda delete-function --function-name $LAMBDA_FUNCTION_NAME --region $REGION

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id $API_ID --region $REGION

# Detach Policies and Delete IAM Roles
aws iam detach-role-policy --role-name $EC2_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam remove-role-from-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --role-name $EC2_ROLE_NAME
aws iam delete-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME
aws iam delete-role --role-name $EC2_ROLE_NAME

aws iam detach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name $LAMBDA_ROLE_NAME

# Delete Key Pair
aws ec2 delete-key-pair --key-name $KEY_PAIR_NAME --region $REGION
rm -f $KEY_PAIR_NAME.pem

# Delete Security Groups
aws ec2 delete-security-group --group-id $EC2_SECURITY_GROUP_ID --region $REGION
aws ec2 delete-security-group --group-id $RDS_SECURITY_GROUP_ID --region $REGION

# Delete RDS Subnet Group
aws rds delete-db-subnet-group --db-subnet-group-name mydbsubnetgroup-$RANDOM_ID --region $REGION

# Delete Subnets
for SUBNET_ID in "${PUBLIC_SUBNET_IDS[@]}"; do
    aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION
done
for SUBNET_ID in "${PRIVATE_SUBNET_IDS[@]}"; do
    aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION
done

# Detach and Delete Internet Gateway
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION

# Delete Route Tables
aws ec2 delete-route-table --route-table-id $PUBLIC_ROUTE_TABLE_ID --region $REGION
aws ec2 delete-route-table --route-table-id $PRIVATE_ROUTE_TABLE_ID --region $REGION

# Delete VPC
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION