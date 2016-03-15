#! /bin/bash

NAME=$1
DESC=$2

EC2_REGIONS=("us-east-1" "eu-central-1" "us-west-1" "ap-southeast-1" "us-west-2" "eu-west-1" "ap-northeast-1")
EC2_REGIONS=("ap-southeast-2" "sa-east-1")

for region in ${EC2_REGIONS[@]}; do
	ec2-create-group $NAME --description $DESC --region $region
	ec2-authorize $NAME -P tcp -p 46656-46657 --region $region
	ec2-authorize $NAME -P tcp -p 2376 --region $region
done

