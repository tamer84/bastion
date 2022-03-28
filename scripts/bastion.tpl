#!/usr/bin/env bash

sudo apt-get update
sudo apt-get --assume-yes install nginx jq python
# install aws cli
aws_zip_name="awscliv2.zip"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o $aws_zip_name
python3 -c "from zipfile import PyZipFile; PyZipFile( '''$aws_zip_name''' ).extractall()";
sudo chmod -R 500 ./aws
sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin
sudo rm -rf ./aws
sudo rm ./$aws_zip_name

# install cloudwatch log agent for nginx access loging
sudo echo "[/var/log/nginx/access.log]" > /tmp/awslogs.conf
sudo echo "datetime_format = %Y-%m-%d %H:%M:%S" >> /tmp/awslogs.conf
sudo echo "file = /var/log/nginx/access.log" >> /tmp/awslogs.conf
sudo echo "buffer_duration = 5000" >> /tmp/awslogs.conf
sudo echo "log_stream_name = nginx_access_log" >> /tmp/awslogs.conf
sudo echo "initial_position = start_of_file" >> /tmp/awslogs.conf
sudo echo "log_group_name = ${jsondecode(additional_vars).log_group}" >> /tmp/awslogs.conf

sudo echo "[/var/log/nginx/error.log]" >> /tmp/awslogs.conf
sudo echo "datetime_format = %Y-%m-%d %H:%M:%S" >> /tmp/awslogs.conf
sudo echo "file = /var/log/nginx/error.log" >> /tmp/awslogs.conf
sudo echo "buffer_duration = 5000" >> /tmp/awslogs.conf
sudo echo "log_stream_name = nginx_log" >> /tmp/awslogs.conf
sudo echo "initial_position = start_of_file" >> /tmp/awslogs.conf
sudo echo "log_group_name = ${jsondecode(additional_vars).log_group}" >> /tmp/awslogs.conf

curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
sudo python ./awslogs-agent-setup.py --region ${jsondecode(additional_vars).nginx_port} -n -c /tmp/awslogs.conf

cd /etc/nginx
sudo chown -R ubuntu:ubuntu *

# Add ssl certificates
sudo echo "${private_key_pem}" >> /etc/nginx/conf.d/private_key.pem
sudo echo "${certificate_pem}" >> /etc/nginx/conf.d/certificate.crt

nginx_config_file="/etc/nginx/conf.d/tango-proxy.conf"
nginx_credentials_file="/etc/nginx/conf.d/htpasswd"
nginx_index_file="/usr/share/nginx/html/index.html"
credentials_script_file="/etc/nginx/conf.d/updateCredentials.sh"
service_update_script_file="/etc/nginx/conf.d/update_proxy_list.sh"

sudo echo "server { " > $nginx_config_file
sudo echo "    listen       ${jsondecode(additional_vars).nginx_port} ssl; " >> $nginx_config_file
sudo echo "    server_name  localhost; " >> $nginx_config_file
# Disable server version from header
sudo echo "    server_tokens off; " >>  $nginx_config_file

sudo echo "    ssl_certificate /etc/nginx/conf.d/certificate.crt; " >> $nginx_config_file
sudo echo "    ssl_certificate_key /etc/nginx/conf.d/private_key.pem; " >> $nginx_config_file
sudo echo "    ssl_protocols TLSv1.2 TLSv1.3; " >> $nginx_config_file
sudo echo "    ssl_ciphers \"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA HIGH !RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS\"; " >> $nginx_config_file

sudo echo "    auth_basic           \"Developer lambda access\"; " >> $nginx_config_file
sudo echo "    auth_basic_user_file conf.d/htpasswd; " >> $nginx_config_file

# redirect http requests to https
sudo echo "    error_page 497 https://\$host:\$server_port\$request_uri;"  >> $nginx_config_file
sudo echo "}" >> $nginx_config_file

# script to get credentials from secretsmanager and add them to nginx
sudo echo "#!/bin/bash"  > $credentials_script_file
sudo echo "secretstring=\$(aws secretsmanager get-secret-value --secret-id ${jsondecode(additional_vars).secret_arn} | sed 's/[\]//g' | sed 's/\"{/{/g' | sed 's/}\"/}/g' | jq \".SecretString\")"  >> $credentials_script_file
sudo echo "user=\$(jq \".username\" <<< \$secretstring | sed 's/\"//g')"  >> $credentials_script_file
sudo echo "password=\$(jq \".password\" <<< \$secretstring | sed 's/\"//g')"  >> $credentials_script_file
sudo echo "hashpassword=\$(openssl passwd -apr1 \$password)" >> $credentials_script_file
#basic authentication for nginx  - kahula / password : Check secrets Manager nginx
sudo echo "echo \"\$user:\$hashpassword\" > $nginx_credentials_file" >> $credentials_script_file
sudo echo "sudo service nginx restart" >> $credentials_script_file
sudo chmod 500 $credentials_script_file

#HTML index listing the services
sudo echo "<!doctype html>" > $nginx_index_file
sudo echo "<html lang=\"en\">" >> $nginx_index_file
sudo echo " <head>" >> $nginx_index_file
sudo echo "     <meta charset=\"utf-8\">" >> $nginx_index_file
sudo echo "     <title>Endpoint List</title>" >> $nginx_index_file
sudo echo "     <style>" >> $nginx_index_file
sudo echo "         body {" >> $nginx_index_file
sudo echo "             witdh: 35em;" >> $nginx_index_file
sudo echo "             margin: 0 auto;" >> $nginx_index_file
sudo echo "         }" >> $nginx_index_file
sudo echo "     </style>" >> $nginx_index_file
sudo echo " </head>" >> $nginx_index_file
sudo echo " <body>" >> $nginx_index_file
sudo echo " <h3>Endpoint List </h3>" >> $nginx_index_file
sudo echo " </body>" >> $nginx_index_file
sudo echo "</html>" >> $nginx_index_file

# Script to replace/Update proxy locations
sudo echo "#!/bin/bash" > $service_update_script_file
sudo echo "service_list=\"\$1\" " >> $service_update_script_file
sudo echo "#Remove locations and endpoint list" >> $service_update_script_file
sudo echo "conf_file=\"$nginx_config_file\"" >>$service_update_script_file
sudo echo "html_file=\"$nginx_index_file\"" >>$service_update_script_file
sudo echo "sed '/location .*/,/.*\}/d' \$conf_file > conf.temp && mv conf.temp \$conf_file" >>$service_update_script_file
sudo echo "sed '/<a .*/d' \$html_file > html.temp && mv html.temp \$html_file" >>$service_update_script_file
sudo echo "for i in \$(seq 0 \$((\$(jq length <<< \$service_list)-1))); do" >>$service_update_script_file
sudo echo "   name=\$(jq \".[\$i]\" <<< \$service_list | jq \".name\" | sed 's/\"//g')" >>$service_update_script_file
sudo echo "   url=\$(jq \".[\$i]\" <<< \$service_list | jq \".url\" | sed 's/\"//g')" >>$service_update_script_file
sudo echo "   #Add new locations" >>$service_update_script_file
sudo echo "   awk '1;/auth_basic_user_file .*/{ print \"    location /'\$name' \{\"; print \"        proxy_pass  '\$url';\"; print \"    \}\";}' \$conf_file > conf.temp && mv conf.temp \$conf_file" >>$service_update_script_file
sudo echo "   awk '1;/<h3>.*/{ print \"  <a href=\\\"\/'\$name'\\\">'\$name'</a><br>\";}' \$html_file > html.temp && mv html.temp \$html_file" >> $service_update_script_file
sudo echo "done" >>$service_update_script_file
sudo echo "sudo service nginx restart" >>$service_update_script_file
chmod 500 $service_update_script_file

# Get credentials from secrets manager and add them to nginx
sudo $credentials_script_file

sudo snap install amazon-ssm-agent --classic
sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

#dont know why this is needed, but makes it work
sudo service nginx restart

sudo service awslogs restart
