#!/usr/bin/env bash

# Arguments
CLUSTER_ID=$1

# Load settings
PACKAGE_NAME=$(cat settings.json | jq -r '.packageName')
PACKAGE_VERSION=$(cat settings.json | jq -r '.packageVersion')

# Arguments (dynamic)
DOMAIN=$CLUSTER_ID

# Terminate all instances
OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
INSTANCES=$(echo $OUTPUT | jq -r '.Reservations | length')

echo "Terminating $INSTANCES instances ..."

I=0

while [ $INSTANCES != $I ]
do
  INSTANCE_ID=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].InstanceId")
  aws ec2 terminate-instances --instance-ids $INSTANCE_ID > /dev/null
  let "I++"
done

echo -n "Waiting for instances to be all stopped ... ($INSTANCES runnings)"

while [ $INSTANCES != 0 ]
do
  sleep 1
  OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
  INSTANCES=$(echo $OUTPUT | jq -r '.Reservations | length')
  echo -en "\e[0K\r"
  echo -n "Waiting for instances to be all stopped ... ($INSTANCES runnings)"
done

echo " done."

# Remove Route53 records and domain
OUTPUT=$(aws route53 list-hosted-zones-by-name --dns-name $DOMAIN)
ZONE_ID_RAW=$(echo $OUTPUT | jq -r '.HostedZones[0].Id')
ZONE_ID=${ZONE_ID_RAW:12}

OUTPUT=$(aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID)
RECORD=$(echo $OUTPUT | jq -r '.ResourceRecordSets[2]')

CHANGE="{\"Changes\": [{\"Action\": \"DELETE\", \"ResourceRecordSet\": $RECORD }]}"
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "$CHANGE" > /dev/null

aws route53 delete-hosted-zone --id $ZONE_ID > /dev/null

# TODO Remove VPC
OUTPUT=$(aws ec2 describe-vpcs --filters Name=tag-key,Values=name,Name=tag-value,Values=$CLUSTER_ID)
VPC_ID=$(echo $OUTPUT | jq -r '.Vpcs[0].VpcId')
echo "Please remove VPC with id '$VPC_ID' and name '$CLUSTER_ID' in the AWS console!"
# TODO We must first delete all the dependencies! the console do it automatically... but there is no API for it.
# aws ec2 delete-vpc --vpc-id $VPC_ID > /dev/null
