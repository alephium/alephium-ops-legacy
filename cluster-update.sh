#!/usr/bin/env bash

# Arguments
CLUSTER_ID=$1

# Load settings
PACKAGE_NAME=$(cat settings.json | jq -r '.packageName')
PACKAGE_VERSION=$(cat settings.json | jq -r '.packageVersion')

PACKAGE_FILE=$PACKAGE_NAME-$PACKAGE_VERSION.zip

# Commands
scp='scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i default.pem'
ssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T -i default.pem'

# List all instances
OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
INSTANCES=$(echo $OUTPUT | jq -r '.Reservations | length')

I=0

chmod 400 default.pem

# Update package
while [ $INSTANCES != $I ]
do
  INSTANCE_ID=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].InstanceId")

  PUBLIC_IP=$(echo $OUTPUT | jq -r ".Reservations[$I].Instances[0].PublicIpAddress")

  echo ""
  echo "Connecting to $INSTANCE_ID at $PUBLIC_IP to update package..."

  $ssh ec2-user@$PUBLIC_IP << EOF
    sudo killall -9 java
    sudo rm -rf /srv/*
EOF

  $scp $PACKAGE_FILE ec2-user@$PUBLIC_IP:~

  $ssh ec2-user@$PUBLIC_IP << EOF
    cd /srv
    sudo unzip ~/$PACKAGE_FILE; rm ~/$PACKAGE_FILE
    sudo ln -s /srv/$PACKAGE_NAME-$PACKAGE_VERSION/bin/$PACKAGE_NAME /srv/app

    sudo su -

    echo "" >> /var/log/cloud-init-output.log
    echo "$(date) - $PACKAGE_FILE - update" >> /var/log/cloud-init-output.log
    echo "" >> /var/log/cloud-init-output.log

    nohup /srv/app >> /var/log/cloud-init-output.log &
EOF

  let "I++"
done

echo ""
echo "Done."
