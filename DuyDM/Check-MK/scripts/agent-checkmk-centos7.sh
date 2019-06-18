#!/bin/bash
#duydm
#Install Agent Check_Mk on Centos7 cum VZ

echocolor "Nhap ip Check_Mk server 103.101.161.204"
sleep 3
read ipserver

yum install wget -y
wget https://mon.cloud365.vn/mon/check_mk/agents/check-mk-agent-1.5.0p18-1.noarch.rpm
yum install xinetd -y
systemctl start xinetd
systemctl enable xinetd
rpm -ivh check-mk-agent-*
cp /etc/xinetd.d/check_mk /etc/xinetd.d/check_mk.bk
sed -i 's/#only_from      = 127.0.0.1 10.0.20.1 10.0.20.2/only_from      = '$ipserver'/g'  /etc/xinetd.d/check_mk
systemctl restart xinetd
systemctl status xinetd

echo "Cai dat agent check_mk Ok"

echocolor "Cai dat Check_Mk Inventory"
sleep 3

wget -O /usr/lib/check_mk_agent/local/mk_inventory  http://mon.cloud365.vn/mon/check_mk/agents/plugins/mk_inventory.linux
chmod +x /usr/lib/check_mk_agent/local/mk_inventory  


echocolor "Cai dat smart disk"
sleep 3

yum install smartmontools -y
cd /usr/lib/check_mk_agent/plugins
wget https://raw.githubusercontent.com/uncelvel/tutorial-ceph/master/docs/monitor/check_mk/plugins/smart
chmod +x smart
./smart


echo "Test cd /usr/lib/check_mk_agent/plugins, cd /usr/lib/check_mk_agent/local/mk_inventorys"


