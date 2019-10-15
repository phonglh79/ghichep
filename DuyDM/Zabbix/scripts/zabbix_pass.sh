#!/bin/bash
#duydm
#Install zabbix 4.0 change pass Admin, Mysql, Zabbix_user

old_passMysql="9TtwZBSm"
old_passAdminNew="9TtwZBSm"
old_passDbZabbix="9TtwZBSm"
userMysql="root"

new_passMysql="DaCwdJ96"
new_passAdminNew="DaCwdJ96"
new_passDbZabbix="DaCwdJ96"
# Change pass root mysql

mysqladmin --user=root --password=$old_passMysql password $new_passMysql

# Change pass Zabbix_user

mysqladmin --user=zabbix_user --password=$old_passDbZabbix password $new_passDbZabbix

sed -i "s/DBPassword=$old_passDbZabbix/DBPassword=$new_passDbZabbix/g" /etc/zabbix/zabbix_server.conf
sed -i "s/$DB['PASSWORD'] = '9TtwZBSm';/$DB['PASSWORD'] = '$new_passDbZabbix';/g" /etc/zabbix/web/zabbix.conf.php


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

mysqladmin --user=zabbix_user --password=DbZabbix12password 9TtwZBSm