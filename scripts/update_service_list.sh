#!/bin/bash
instance_id=$1
json=$2
escaped_json=$(sed "s/\"/\\\\\\\\\\\\\"/g" <<< $2)
aws ssm send-command --document-name "AWS-RunShellScript" --document-version "1" --targets '[{"Key":"InstanceIds","Values":["'$instance_id'"]}]' --parameters '{"commands":["./update_proxy_list.sh \"'$escaped_json'\""],"workingDirectory":["/etc/nginx/conf.d"],"executionTimeout":["3600"]}' --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --region eu-central-1