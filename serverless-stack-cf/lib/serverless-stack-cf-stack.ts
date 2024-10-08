import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as path from 'path';
import * as cfninc from 'aws-cdk-lib/cloudformation-include';

export class ServerlessStackCfStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Include the CloudFormation template
    new cfninc.CfnInclude(this, 'IncludedTemplate', {
      templateFile: path.resolve(__dirname, '../../sls-template.yml'),
      parameters: {
        LambdaFunction00MyLambdaFunction1325700kVilcCodeS3Keydw9i0: "lambda_function.zip", //Update this (You manually create a bucket to host your code)
        LambdaFunction00MyLambdaFunction1325700kVilcCodeS3BucketFOeva: "lambda-code-toptal-clickops-workshop" //Update this also
      }
    });
  }
}