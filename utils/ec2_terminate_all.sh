#! /bin/bash

EC2_REGIONS=("us-east-1" "eu-central-1" "us-west-1" "ap-southeast-1" "us-west-2" "eu-west-1" "ap-northeast-1" "ap-southeast-2" "sa-east-1")

for region in ${EC2_REGIONS[@]}; do
	ec2-describe-instances --region $region | grep INSTANCE | awk '{print $2}' | xargs ec2-terminate-instances --region $region
done

