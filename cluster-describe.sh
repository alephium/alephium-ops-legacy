#!/usr/bin/env bash

# Arguments
CLUSTER_ID=$1

# Load settings
PACKAGE_NAME=$(cat settings.json | jq -r '.packageName')
PACKAGE_VERSION=$(cat settings.json | jq -r '.packageVersion')

# List all instances
OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
INSTANCES=$(echo $OUTPUT | jq -r '.Reservations | length')

I=0

echo "["

# Print IP addresses
while [ $INSTANCES != $I ]
do
  INSTANCE_ID=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].InstanceId")

  PRIVATE_IP=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].PrivateIpAddress")
  PUBLIC_IP=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].PublicIpAddress")

  echo -n "  {\"InstanceId\": \"$INSTANCE_ID\", \"PrivateIp\": \"$PRIVATE_IP\", \"PublicIp\": \"$PUBLIC_IP\"}"

  let "I++"
  if [ $I != $INSTANCES ]; then
    echo ","
  else
    echo ""
  fi
done

echo "]"

