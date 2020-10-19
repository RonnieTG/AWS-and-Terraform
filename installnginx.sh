#!/bin/bash
sudo apt update
sudo apt install nginx -y
sed -i 's/nginx/OpsSchool Rules/g' /var/www/html/index.nginx-debian.html
sed -i '15,23d' /var/www/html/index.nginx-debian.html
service nginx restart