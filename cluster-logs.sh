#!/usr/bin/env bash

# Arguments
CLUSTER_ID=$1

# Commands
scp='scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i default.pem'
ssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T -i default.pem'

# List all instances
OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
INSTANCES=$(echo $OUTPUT | jq -r '.Reservations | length')

I=0

echo ""
echo Fetching logs on cluster \"$CLUSTER_ID\" containing $INSTANCES instances.
echo ""

LOGS=$TMPDIR/alephium-log
mkdir -p $LOGS

while [ $INSTANCES != $I ]
do
  INSTANCE_ID=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].InstanceId")
  PUBLIC_IP=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].PublicIpAddress")

  $scp ec2-user@$PUBLIC_IP:/var/log/alephium.log $LOGS/$CLUSTER_ID-$I.log

  let "I++"
done
