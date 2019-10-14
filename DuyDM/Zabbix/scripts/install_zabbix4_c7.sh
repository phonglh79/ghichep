#!/bin/bash
#duydm
#Install zabbix 4.0 Centos7.7

#---------------------------
#Download repo zabbix và install package
#---------------------------
yum install epel-release wget -y
rpm -ivh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm
yum -y install zabbix-server-mysql zabbix-web-mysql mysql mariadb-server httpd php

#---------------------------
# Create Db
#---------------------------

userMysql="root"
passMysql="duydm"
portMysql="3306"
hostMysql="localhost"
nameDbZabbix="zabbix_db"
userDbZabbix="zabbix_user"
passDbZabbix="duydm"
passAdminNew="domanhduy"

systemctl start mariadb
systemctl enable mariadb

mysql_secure_installation <<EOF

y
$passMysql
$passMysql
y
y
y
y
EOF


cat << EOF |mysql -u$userMysql -p$passMysql
DROP DATABASE IF EXISTS zabbix_db;
create database zabbix_db character set utf8 collate utf8_bin;
grant all privileges on zabbix_db.* to zabbix_user@localhost identified by '$passDbZabbix';
flush privileges;
exit
EOF

#---------------------------
#Import database zabbix
#---------------------------
cd /usr/share/doc/zabbix-server-mysql-4.0.13
gunzip create.sql.gz
mysql -u$userMysql -p$passMysql zabbix_db < create.sql

#---------------------------
#Config DB
# edit vi /etc/zabbix/zabbix_server.conf
#---------------------------
sed -i 's/# DBHost=localhost/DBHost=localhost/g' /etc/zabbix/zabbix_server.conf
sed -i "s/DBName=zabbix/DBName=$nameDbZabbix/g" /etc/zabbix/zabbix_server.conf
sed -i "s/DBUser=zabbix/DBUser=$userDbZabbix/g" /etc/zabbix/zabbix_server.conf
sed -i "s/# DBPassword=/DBPassword=$passDbZabbix/g" /etc/zabbix/zabbix_server.conf
#---------------------------
#Configure PHP Setting
#---------------------------
sed -i 's/max_execution_time = 30/max_execution_time = 600/g' /etc/php.ini
sed -i 's/max_input_time = 60/max_input_time = 600/g' /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/g' /etc/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 32M/g' /etc/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 16M/g' /etc/php.ini
echo "date.timezone = Asia/Ho_Chi_Minh" >> /etc/php.ini
#---------------------------
#Change pass Admin zabbix
#---------------------------
cat << EOF |mysql -u$userMysql -p$passMysql
use zabbix_db;
update users set passwd=md5('$passAdminNew') where alias='Admin';
flush privileges;
exit

EOF

systemctl restart mariadb
#---------------------------
#Restart service
#---------------------------
systemctl start zabbix-server
systemctl enable zabbix-server
systemctl start httpd
systemctl enable httpd
systemctl restart zabbix-server
systemctl restart httpd


