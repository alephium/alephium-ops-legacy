#!/usr/bin/env sh

# TODO FIX
echo "This script is currently broken, please remove the AMI and the snapshot by hand."
exit 1

# No arguments

# Load settings
PACKAGE_NAME=$(cat settings.json | jq -r '.packageName')
PACKAGE_VERSION=$(cat settings.json | jq -r '.packageVersion')

# Find and deregister AMI.
OUTPUT=$(aws ec2 describe-images --filters Name=tag-key,Values=name,Name=tag-value,Values=$PACKAGE_NAME-$PACKAGE_VERSION --owners self)
IMAGE_ID=$(echo $OUTPUT | jq -r '.Images[0].ImageId')

if [ "$IMAGE_ID" == "null" ]; then
  echo "Amazon Machine Image not found."
  exit 1
fi

echo -n "Deregister image $IMAGE_ID ..."
aws ec2 deregister-image --image-id $IMAGE_ID > /dev/null
aws ec2 delete-tags --resources $IMAGE_ID > /dev/null

while [ "$IMAGE_ID" != "null" ];
do
  sleep 1
  OUTPUT=$(aws ec2 describe-images --filters Name=tag-key,Values=name,Name=tag-value,Values=$PACKAGE_NAME-$PACKAGE_VERSION --owners self)
  IMAGE_ID=$(echo $OUTPUT | jq -r '.Images[0].ImageId')
  echo -n "."
done

echo " done."

# Remove snapshot
OUTPUT=$(aws ec2 describe-snapshots --filters Name=tag-key,Values=name,Name=tag-value,Values=$PACKAGE_NAME-$PACKAGE_VERSION)
SNAPSHOT_ID=$(echo $OUTPUT | jq -r '.Snapshots[0].SnapshotId')

echo "Remove snapshot $SNAPSHOT_ID ..."
aws ec2 delete-snapshot --snapshot-id $SNAPSHOT_ID > /dev/null
aws ec2 delete-tags --resources $SNAPSHOT_ID > /dev/null
