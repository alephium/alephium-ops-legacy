#!/usr/bin/env sh

# No arguments

# Load settings
INSTANCE_TYPE=$(cat settings.json | jq -r '.instanceType')
KEY_PAIR=$(cat settings.json | jq -r '.keyPair')
PACKAGE_NAME=$(cat settings.json | jq -r '.packageName')
PACKAGE_VERSION=$(cat settings.json | jq -r '.packageVersion')

PACKAGE_FILE=$PACKAGE_NAME-$PACKAGE_VERSION.zip

# Commands
scp='scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i default.pem'
ssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T -i default.pem'

# Initialize default security group if requiered
OUTPUT=$(aws ec2  describe-security-groups --filters Name=tag-key,Values=name,Name=tag-value,Values=images)
SECURITY_GROUP_ID=$(echo $OUTPUT | jq -r '.SecurityGroups[0].GroupId')
if [ "$SECURITY_GROUP_ID" == "null" ]; then
  echo "Initialize default security group for images ..."
  OUTPUT=$(aws ec2 describe-security-groups)
  SECURITY_GROUP_ID=$(echo $OUTPUT | jq -r '.SecurityGroups[0].GroupId')
  aws ec2 create-tags --resources $SECURITY_GROUP_ID --tags Key=Name,Value=images > /dev/null
  aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null
fi

# Check if an AMI for this package version already exists
OUTPUT=$(aws ec2 describe-images --filters Name=tag-key,Values=name,Name=tag-value,Values=$PACKAGE_NAME-$PACKAGE_VERSION --owners self)
IMAGE_ID=$(echo $OUTPUT | jq -r '.Images[0].ImageId')
if [ "$IMAGE_ID" != "null" ]; then
  echo "An image $IMAGE_ID already exists for $PACKAGE_NAME-$PACKAGE_VERSION, please run './image-delete.sh' before trying to recreate it."
  exit 1
fi

# Create and start instance
OUTPUT=$(aws ec2 run-instances --count 1 --image-id=ami-40142d25 --instance-type $INSTANCE_TYPE --key-name $KEY_PAIR --security-group-ids $SECURITY_GROUP_ID )
INSTANCE_ID=$(echo $OUTPUT | jq -r '.Instances[0].InstanceId')
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=$PACKAGE_NAME-$PACKAGE_VERSION > /dev/null

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

$ssh ec2-user@$PUBLIC_IP << EOF
  sudo yum update -y
  sudo yum remove -y java
  sudo yum install -y java-1.8.0-openjdk
EOF

# Copy and install application
$scp $PACKAGE_FILE ec2-user@$PUBLIC_IP:~

$ssh ec2-user@$PUBLIC_IP << EOF
  cd /srv
  sudo unzip ~/$PACKAGE_FILE; rm ~/$PACKAGE_FILE
  sudo ln -s /srv/$PACKAGE_NAME-$PACKAGE_VERSION/bin/$PACKAGE_NAME /srv/app
EOF

# Create the AMI image
echo ""
echo -n "Create image ..."
OUTPUT=$(aws ec2 create-image --instance-id $INSTANCE_ID --name $PACKAGE_NAME-$PACKAGE_VERSION)
IMAGE_ID=$(echo $OUTPUT | jq -r '.ImageId')
aws ec2 create-tags --resources $IMAGE_ID --tags Key=Name,Value=$PACKAGE_NAME-$PACKAGE_VERSION > /dev/null

OUTPUT=$(aws ec2 describe-images --filters Name=name,Values=$PACKAGE_NAME-$PACKAGE_VERSION)
IMAGE_STATE=$(echo $OUTPUT | jq -r '.Images[0].State')

while [ "$IMAGE_STATE" != "available" ]
do
  sleep 1
  OUTPUT=$(aws ec2 describe-images --filters Name=name,Values=$PACKAGE_NAME-$PACKAGE_VERSION)
  IMAGE_STATE=$(echo $OUTPUT | jq -r '.Images[0].State')
  echo -n "."
done

echo " done."

# Tag volume and snapshot
OUTPUT=$(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$INSTANCE_ID)
VOLUME_ID=$(echo $OUTPUT | jq -r '.Volumes[0].VolumeId')
aws ec2 create-tags --resources $VOLUME_ID --tags Key=Name,Value=$PACKAGE_NAME-$PACKAGE_VERSION > /dev/null

OUTPUT=$(aws ec2 describe-snapshots --filters Name=volume-id,Values=$VOLUME_ID)
SNAPSHOT_ID=$(echo $OUTPUT | jq -r '.Snapshots[0].SnapshotId')
aws ec2 create-tags --resources $SNAPSHOT_ID --tags Key=Name,Value=$PACKAGE_NAME-$PACKAGE_VERSION > /dev/null

# Terminate instance and untag it
aws ec2 terminate-instances --instance-ids $INSTANCE_ID > /dev/null
aws ec2 delete-tags --resources $INSTANCE_ID > /dev/null

# Finish
echo ""
echo "Amazon Machine Image '$PACKAGE_NAME-$PACKAGE_VERSION' is ready: '$IMAGE_ID'"
echo ""

