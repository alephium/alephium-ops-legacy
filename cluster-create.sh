#!/usr/bin/env sh

# Arguments
CLUSTER_ID=$1
CLUSTER_SIZE=$2 # [1 >=< (2046 - 10)] - Change CIDR to increase, first ten addresses are reserved by AWS.

# Load settings
INSTANCE_TYPE=$(cat settings.json | jq -r '.instanceType')
KEY_PAIR=$(cat settings.json | jq -r '.keyPair')
PACKAGE_NAME=$(cat settings.json | jq -r '.packageName')
PACKAGE_VERSION=$(cat settings.json | jq -r '.packageVersion')

# Constants
CIDR=10.0.0.0/21

# Find image
echo "Finding image for '$PACKAGE_NAME-$PACKAGE_VERSION' ..."
OUTPUT=$(aws ec2 describe-images --filters Name=tag-key,Values=name,Name=tag-value,Values=$PACKAGE_NAME-$PACKAGE_VERSION --owners self)
IMAGE_ID=$(echo $OUTPUT | jq -r '.Images[0].ImageId')
IMAGE_STATE=$(echo $OUTPUT | jq -r '.Images[0].State')

if [ "$IMAGE_ID" == "null" ]; then
  echo "Amazon Machine Image not found. (Did you run './build.sh' first?)"
  exit 1
fi

if [ "$IMAGE_STATE" != "available" ]; then
  echo "Amazon Machine Image found but not available yet."
  echo ""
  echo "Please wait or check AMI status in the AWS console..."
  exit 1
fi

# Create VPC and Subnet ...
echo "Creating VPC and Subnet with name '$CLUSTER_ID' ..."

OUTPUT=$(aws ec2 create-vpc --cidr-block $CIDR)
VPC_ID=$(echo $OUTPUT | jq -r '.Vpc.VpcId')
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$CLUSTER_ID > /dev/null

OUTPUT=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $CIDR)
SUBNET_ID=$(echo $OUTPUT | jq -r '.Subnet.SubnetId')
aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=$CLUSTER_ID > /dev/null
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch  > /dev/null

# ... create and attach internet gateway, then route it to the subnet.
OUTPUT=$(aws ec2 create-internet-gateway)
GATEWAY_ID=$(echo $OUTPUT | jq -r '.InternetGateway.InternetGatewayId')
aws ec2 attach-internet-gateway --internet-gateway-id $GATEWAY_ID --vpc-id $VPC_ID > /dev/null
aws ec2 create-tags --resources $GATEWAY_ID --tags Key=Name,Value=$CLUSTER_ID > /dev/null

OUTPUT=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID)
ROUTE_TABLE_ID=$(echo $OUTPUT | jq -r '.RouteTables[0].RouteTableId')
aws ec2 create-tags --resources $ROUTE_TABLE_ID --tags Key=Name,Value=$CLUSTER_ID > /dev/null

aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $GATEWAY_ID > /dev/null

# Find default security group for this VPC and authorize SSH, WebSockets
OUTPUT=$(aws ec2  describe-security-groups --filters Name=vpc-id,Values=$VPC_ID)
SECURITY_GROUP_ID=$(echo $OUTPUT | jq -r '.SecurityGroups[0].GroupId')

aws ec2 create-tags --resources $SECURITY_GROUP_ID --tags Key=Name,Value=$CLUSTER_ID > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 > /dev/null

# Generate IPs
echo "Enumerating $CIDR IPs for $VPC_ID ..."
IPs=$(nmap -sL $CIDR | grep "Nmap scan report" | awk '{print $NF}' |  tail -n +11 | head -$CLUSTER_SIZE)

# Create EC2 instances
echo -n "Launching instances with image $IMAGE_ID ..."
for IP in $IPs; do
  OUTPUT=$(aws ec2 run-instances --count 1 --image-id=$IMAGE_ID --instance-type $INSTANCE_TYPE --key-name $KEY_PAIR --security-group-ids $SECURITY_GROUP_ID --subnet-id $SUBNET_ID --private-ip-address $IP --user-data file://./startup.sh)
  INSTANCE_ID=$(echo $OUTPUT | jq -r '.Instances[0].InstanceId')
  aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=$CLUSTER_ID > /dev/null
  echo -n "."
done

echo " done."

# Waiting for all instances to be ready
OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=Name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
INSTANCES=$(echo $OUTPUT | jq -r '.Reservations[0].Instances | length')

echo -n "Waiting for instances to be all running ... ($INSTANCES / $CLUSTER_SIZE)"

while [ $INSTANCES != $CLUSTER_SIZE ]
do
  sleep 1
  OUTPUT=$(aws ec2 describe-instances --filters Name=tag-key,Values=Name,Name=tag-value,Values=$CLUSTER_ID,Name=instance-state-name,Values=running)
  INSTANCES=$(echo $OUTPUT | jq -r '.Reservations[0].Instances | length')
  echo -en "\e[0K\r"
  echo -n "Waiting for instances to be all running ... ($INSTANCES / $CLUSTER_SIZE)"
done

echo " done."
