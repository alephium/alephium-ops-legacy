import boto3
import json
import subprocess
import sys

scp = 'scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i default.pem'
ssh = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T -i default.pem'

# Amazon Linux 2 AMI (HVM), SSD Volume Type
image_amzn_ami_x64 = 'ami-02e680c4540db351e'

def call_scp(public_ip, local, target):
    sys_call(scp + ' %s ec2-user@%s:%s'%(local, public_ip, target))

def call_ssh(public_ip, script):
    print(sys_process(ssh + ' ec2-user@%s'%(public_ip), script))

def security_group_find_or_create(ec2, vpc_id, name, ports):
    filters = [{'Name': 'tag:Name', 'Values': [name]}]
    groups = ec2.describe_security_groups(Filters=filters)['SecurityGroups']
    if len(groups) < 1:
        group_id = ec2.create_security_group(GroupName=name, Description=name, VpcId=vpc_id)['GroupId']
        group = boto3.resource('ec2').SecurityGroup(group_id)
        group.create_tags(Tags=[{'Key':'Name', 'Value': name}])
        security_group_ingress_authorize(group, ports)
        return group_id
    else:
        return groups[0]['GroupId']

def security_group_ingress_authorize(group, ports):
    for port in ports:
        group.authorize_ingress(
            CidrIp='0.0.0.0/0',
            FromPort=port,
            ToPort=port,
            IpProtocol='tcp'
        )

def settings_read():
    with open('settings.json') as json_data:
        data = json.load(json_data,) 
    return data

def sys_call(cmd):
    return subprocess.call([cmd], shell=True)

def sys_process(cmd, stdin):
    p = subprocess.Popen([cmd], shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (out, _) = p.communicate(stdin.encode())
    return out.decode()

def vpc_default(ec2):
    vpcs = ec2.describe_vpcs(Filters=[{'Name': 'isDefault', 'Values': ['true']}])['Vpcs']
    if len(vpcs) < 1:
        print("Default VPC not found!")
        sys.exit(1)
    return vpcs[0]['VpcId']

