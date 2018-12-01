# WIP

- Automate creation of `default` security group
  - The security group must have an inbound rule to allow remote SSH from source 0.0.0.0/0
    - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-network-security.html#vpc-security-groups

- Automate cluster creation

# Usage

- Populate `.aws/config`
  - https://www.cloudberrylab.com/blog/how-to-find-your-aws-access-key-id-and-secret-access-key-and-register-with-cloudberry-s3-explorer/

- Add `default.pem`
  - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair

- Populate `settings.json`
  - Add package file `<name>-<version>.zip` in project root
