#!/usr/bin/env sh

scp='scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
ssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

# Load settings
INSTANCE_TYPE=$(cat settings.json | jq -r '.instanceType')
KEY_PAIR=$(cat settings.json | jq -r '.keyPair')
PACKAGE_NAME=$(cat settings.json | jq -r '.packageName')
PACKAGE_VERSION=$(cat settings.json | jq -r '.packageVersion')

PACKAGE_FILE=$PACKAGE_NAME-$PACKAGE_VERSION.zip

# Create and start instance
OUTPUT=$(aws ec2 run-instances --count 1 --image-id=ami-40142d25 --instance-type $INSTANCE_TYPE --key-name $KEY_PAIR --security-groups default)
INSTANCE_ID=$(echo $OUTPUT | jq -r '.Instances[0].InstanceId')

echo -n "Starting instance $INSTANCE_ID (from vanilla Linux AMI) ..."

STATE=init

while [ $STATE != "ok" ]
do
  sleep 1
  OUTPUT=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID)
  STATE=$(echo $OUTPUT | jq -r '.InstanceStatuses[0].SystemStatus.Status')
  echo -n "."
done

echo " done."

# Connect to instance and install env
OUTPUT=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID)
PUBLIC_IP=$(echo $OUTPUT | jq -r '.Reservations[0].Instances[0].NetworkInterfaces[0].PrivateIpAddresses[0].Association.PublicIp')

echo "Connecting to $INSTANCE_ID at $PUBLIC_IP to install environment..."
echo ""

chmod 400 default.pem

$ssh -T -i default.pem ec2-user@$PUBLIC_IP << EOF
  sudo yum update -y
  sudo yum remove -y java
  sudo yum install -y java-1.8.0-openjdk
EOF

# Copy and install application
$scp -i default.pem $PACKAGE_FILE ec2-user@$PUBLIC_IP:~

$ssh -T -i default.pem ec2-user@$PUBLIC_IP << EOF
  cd /srv
  sudo unzip ~/$PACKAGE_FILE; rm ~/$PACKAGE_FILE
  sudo ln -s /srv/$PACKAGE_NAME-$PACKAGE_VERSION/bin/$PACKAGE_NAME /srv/app
EOF

# Decommision previous AMI, if exists
OUTPUT=$(aws ec2 describe-images --filters "Name=name,Values=$PACKAGE_NAME-$PACKAGE_VERSION" --owners self --query "Images[*].{ID:ImageId}" )
IMAGE_ID=$(echo $OUTPUT | jq -r '.[0].ID')

if [ "$IMAGE_ID" != "null" ]; then
  aws ec2 deregister-image --image-id $IMAGE_ID
fi

# Create AMI
OUTPUT=$(aws ec2 create-image --instance-id $INSTANCE_ID --name $PACKAGE_NAME-$PACKAGE_VERSION)
IMAGE_ID=$(echo $OUTPUT | jq -r '.ImageId')

echo ""
echo "Amazon Machine Image '$PACKAGE_NAME-$PACKAGE_VERSION' is ready: '$IMAGE_ID'"
echo ""


# Cleanup
aws ec2 terminate-instances --instance-ids $INSTANCE_ID > /dev/null
