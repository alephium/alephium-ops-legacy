# Install

See `buildInputs` value in the file `default.nix` to get the list of requiered tools, also review the environment variables defined in that file.

# Usage

### Workflow

One should first create an AMI (Amazon Machine Image) for a given package version, this image will then be used to create one or many VPC clusters.

- image-create
- cluster-create
- cluster-delete
- image-delete

Note: every resources created by `image-create` are tagged using $PACKAGE_NAME-$PACKAGE_VERSION, similarly all resources created by `cluster-create` are tagged using $CLUSTER_ID.

### image-create

- Populate `.aws/config` (copy it from `.aws/config.sample`)
  - https://www.cloudberrylab.com/blog/how-to-find-your-aws-access-key-id-and-secret-access-key-and-register-with-cloudberry-s3-explorer/

- Add `default.pem`
  - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair

- Copy `settings.json.tmpl` as `settings.json` and populate accordingly
  - Add package file `<packageId>.zip` in project root

- Build the AMI image with `./image-create.sh`

### cluster-create

- Once the image is ready, one can start a new cluster with `./cluster-create.sh $CLUSTER_ID`

The EC2 console ("Instances") show public IP addresses of nodes, which can be used to communicate with them.

One can SSH to them, and print the log output.

  
  ssh -i default.pem ec2-user@$IP_ADDRESS
  tail -f /var/log/cloud-init-output.log
  

One can also use `pssh` to access multiple instances at once.

  ./cluster-pssh.sh foo "tail /root/.alephium/logs/alephium.log"

Here is an other example to start mining on the whole cluster.

  ./cluster-pssh.sh foo "curl --data-binary '{"jsonrpc":"2.0","id":"curltext","method":"mining/start","params":[]}' -H 'content-type:text/plain;' http://127.0.0.1:8080/"

## TODO

- Upload the application to a S3 bucket, and then fetch from there.
  - Add `cluster-update`

### cluster-delete

You can delete the cluster once you are done with it using `./cluster-delete.sh $CLUSTER_ID`.

### image-delete

In order to completely remove an image from the ELS storage, one can run `./image-delete.sh`.

This can be used to recreate the image of a same package version with an update package file.
