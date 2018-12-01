#!/usr/bin/env bash

# Arguments
CLUSTER_ID=$1

# Load settings
PACKAGE_ID=$(cat settings.json | jq -r '.packageId')
PACKAGE_APP=$(cat settings.json | jq -r '.packageApp')

PACKAGE_FILE=$PACKAGE_ID.zip

# Commands
scp='scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i default.pem'
ssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T -i default.pem'

# List all instances
OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
INSTANCES=$(echo $OUTPUT | jq -r '.Reservations | length')
CLUSTER_SIZE=$INSTANCES

I=0

chmod 400 default.pem

echo "Rebooting $INSTANCES instances ..."

# Reboot package
while [ $INSTANCES != $I ]
do
  INSTANCE_ID=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].InstanceId")
  aws ec2 reboot-instances --instance-ids $INSTANCE_ID > /dev/null

  let "I++"
done

echo ""
echo "Done."

# Waiting for all instances to be ready
OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=Name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
INSTANCES=$(echo $OUTPUT | jq -r '.Reservations | length')

echo -n "Waiting for instances to be all running ... ($INSTANCES / $CLUSTER_SIZE)"

while [ $INSTANCES != $CLUSTER_SIZE ]
do
  sleep 1
  OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=Name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
  INSTANCES=$(echo $OUTPUT | jq -r '.Reservations | length')
  echo -en "\e[0K\r"
  echo -n "Waiting for instances to be all running ... ($INSTANCES / $CLUSTER_SIZE)"
done

echo " done."
