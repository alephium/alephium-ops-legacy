#!/usr/bin/env bash

# Arguments
CLUSTER_ID=$1
COMMAND=$2

# List all instances
OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
INSTANCES=$(echo $OUTPUT | jq -r '.Reservations | length')

I=0

HOSTS=/tmp/$CLUSTER_ID.hosts

# TODO Optimization: Do not recompute the file if already present (delete file on cluster delete then?)
rm $HOSTS 2> /dev/null

echo ""
echo Accessing cluster \"$CLUSTER_ID\" containing $INSTANCES instances.
echo ""

while [ $INSTANCES != $I ]
do
  INSTANCE_ID=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].InstanceId")

  PUBLIC_IP=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].PublicIpAddress")

  echo ec2-user@$PUBLIC_IP >> $HOSTS

  let "I++"
done

pssh -x "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T -i default.pem" --inline-stdout -h $HOSTS $COMMAND
