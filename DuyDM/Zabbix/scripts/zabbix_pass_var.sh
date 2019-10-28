#!/bin/bash
#duydm
#Install zabbix 4.0 change pass Admin, Mysql, Zabbix_user

old_passMysql="9TtwZBSm"
old_passAdminNew="9TtwZBSm"
old_passDbZabbix="9TtwZBSm"
userMysql="root"

new_passMysql=$1
new_passAdminNew=$2
new_passDbZabbix=$3
# Change pass root mysql

mysqladmin --user=root --password=$old_passMysql password $new_passMysql

# Change pass Zabbix_user

cat << EOF |mysql -u$userMysql -p$new_passMysql
GRANT ALL ON *.* TO zabbix_user@localhost;
flush privileges;
exit
EOF

mysqladmin --user=zabbix_user --password=$old_passDbZabbix password $new_passDbZabbix
sed -i "s/DBPassword=$old_passDbZabbix/DBPassword=$new_passDbZabbix/g" /etc/zabbix/zabbix_server.conf
sed -i "s|\$DB\['PASSWORD'\] = '$old_passDbZabbix'\;|\$DB\['PASSWORD'\] = '$new_passDbZabbix'\;|g" /etc/zabbix/web/zabbix.conf.php

# Change pass root Admin

cat << EOF |mysql -u$userMysql -p$new_passMysql
use zabbix_db;
update users set passwd=md5('$new_passAdminNew') where alias='Admin';
flush privileges;
exit
EOF

systemctl restart zabbix-server
systemctl restart httpd
systemctl restart mariadb

