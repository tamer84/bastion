# bastion


#### Update service-list
In order to update the service list it is only required to change the [service-list on the `main.tf` file](https://github.com/tamer84/bastion/blob/develop/main.tf#L89).

And then run the `terraform apply` command (preferable through the pipeline).

#### Update nginx credentials

As to update nginx credentials without redeploying the bastion, you should be able to run the following command on **your terminal**:
```
terraform init
terraform workspace select {env on which to update the credentials}
instance_id=$(terraform output bastion_server_id)
aws ssm send-command --document-name "AWS-RunShellScript" --document-version "1" --targets '[{"Key":"InstanceIds","Values":["'$instance_id'"]}]' --parameters '{"commands":["./updateCredentials.sh"],"workingDirectory":["/etc/nginx/conf.d"]}' --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --region eu-central-1
```

#### Access to bastion through ssh
The bastion is on a security group blocking every incoming traffic except to the nginx port (8765). Regarding outgoing traffic it is restricted to using HTTP/HTTPS and DNS ports. 
In order to access the shell you should use AWS Systems manager, it should be as simple as : 
```
terraform init
terraform workspace select {env of the bastion}
instance_id=$(terraform output bastion_server_id)
aws ssm start-session --target $instance_id
$
```
