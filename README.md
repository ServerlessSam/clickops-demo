# Welcome To The Click-Ops AWS Cleanup Workshop

This repository is to be used in order to set up a fresh AWS account for the live workshop (or follow asynchronously)

## Workshop Setup Instructions

1) Ensure you have the AWS CLI installed
2) Set up an IAM user/role to use for the workshop. I would recommend using `AWSAdministratorAccess`.
3) Ensure you have authenticated to your AWS account with this IAM entity. This can be verified by running `aws s3 ls` in your terminal (and expect a response of some kind, it can be empty, this is ok).
4) Ensure you have set up the correct AWS region. This can be configured using `aws configure`. The workshop is intended for `eu-west-2` (London) but should work elsewhere with minimal additional steps.
5) **Update** the `REGION="eu-west-2"` and `AMI_ID="ami-0b4c7755cdf0d9219"` in the script to match you're region. You can get the corresponding x86 Amazon Linux AMI for your region from the EC2 console.
5) Run the `init.sh` script in your terminal (`bash init.sh`) - This script will create the following resources in your AWS account:
    -   VPC
    -   2x public subnets
    -   1x private subnet
    -   1x t3.micro EC2 instance (free tier eligible)
    -   1x db.t3.micro RDS instance (free tier eligible)
    -   1x DynamoDB table (scales pricing to zero)
    -   1x S3 bucket (scales pricing to zero)
    -   1x Lambda Function (scales pricing to zero)
    -   1x API Gateway (scales pricing to zero)

    So this shouldn't cost you anything, but be aware that running the script multiple times will duplicate the resources and incur cost. I'd recommend using a throwaway AWS environment for this workshop.
6) Verify the listed resources above were deployed in your account via the AWS console. Check the terminal output for any errors.

This script mimics the click-ops nature of some AWS accounts. The resources are all orphaned without an infrastructure-as-code template defining them. We are going to change that!

## During the Workshop

During the workshop we are going to do the following:
- Generate a CloudFormation template for the EC2, RDS and networking resources, using auto-discovery to locate all networking pieces.
- Generate a CloudFormation template for all the serverless components created via the script.
- Migrate this template to a CDK app via the `cdk migrate` command.
- Migrate the template to a CDK app using the CDK CloudFormation construct.
- Add new resources to this CDK app.
- Migrate this template to a Terraform project.


## After the Workshop

It is important to cleanup after this workshop. I have provided a `teardown.sh` script (genAI generated) which could help in cleaning up all the resources. However we will have moved them all around into new CloudFormation templates etc. I'd recommend deleting the whole AWS account. If that is not possible, then ensure you delete the following by hand:
- 1x t3.micro EC2 instance
- 1x db.t3.micro RDS instance
- 1x API gateway
- 1x S3 bucket
- All CloudFormation templates visable in the console.

If you are having any trouble cleaning up please reach out to me on Slack! (Samuel Lock)