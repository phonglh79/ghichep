#!/bin/bash
#duydm
#Install Agent Check_Mk on Centos6

echo "Nhap ip Check_Mk server"
read ipserver

yum install wget -y
wget https://ms.cloud365.vn/managed/check_mk/agents/check-mk-agent-1.5.0p16-1.noarch.rpm
yum install xinetd -y
chkconfig xinetd on
/etc/init.d/xinetd restart
rpm -ivh check-mk-agent-*
cp /etc/xinetd.d/check_mk /etc/xinetd.d/check_mk.bk
sed -i 's/#only_from      = 127.0.0.1 10.0.20.1 10.0.20.2/only_from      = '$ipserver'/g'  /etc/xinetd.d/check_mk
/etc/init.d/xinetd restart
/etc/init.d/xinetd status

echo "Cai dat agent check_mk Ok"