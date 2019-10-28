# Ghi chép lại các bước cài đặt manual Openstack Queen CentOS 7 trên môi trường VMware ESXi 6.0.0

### Mục lục

[1. Mô hình triển khai](#mohinh)<br>
[2. IP Planning](#planning)<br>
[3. Thiết lập ban đầu](#thietlap)<br>
[4. Cài đặt node controller](#controller)<br>
[5. Cài đặt node compute](#compute)<br>
[6. Truy cập dashboard horizon](#dashboard)<br>

<a name="mohinh"></a>
## 1. Mô hình triển khai

Mô hình triển khai gồm 1 node Controller, 2 node Compute. Triển khai trên môi trường ảo hóa VMware ESXi

![](../images/img-manual/topo-manual.png)

<a name="planning"></a>
## 2. IP Planning

Hình ảnh ở dưới thể hiện phân hoạch địa chỉ IP và cấu hình tối thiểu cho các node cài đặt Openstack.

![](../images/img-manual/Screenshot_933.png)

## 3. Thiết lập ban đầu

**Bật chế độ ảo hóa trong vm trên ESXi**<br>
Ở đây triển khai trên môi trường ảo hóa VMware nên ta phải bật mode ảo hóa đối với máy ảo được tạo ra trên VMware ESXi. Thực hiện và kiểm tra trên cả ba node trển khai Openstack.

+ Sau khi cài đặt xong CentOS 7 tiến hành shutoff và cấu hình enable vmx cho KVM Node trên ESXi Node.

+ SSH vào node VMware di chuyển tới thư mục: `/vmfs/volumes/datastore_name`. Bên trong này sẽ chứa tất cả các file của VM được tạo.

```
cd /vmfs/volumes/datastore_name/Name_VMVKM
```
datastore_name tùy thuộc vào trên của phân vùng lưu trữ disk của VMware

![](../images/img-manual/Screenshot_935.png)

+ Edit file `VM-name.vmx`

Add thêm dòng sau vào cuối file

```
vhv.enable = "TRUE"
```
![](../images/img-manual/Screenshot_936.png)

+ Kiểm tra ID của VM và reload lại VM vừa sửa file VM-name.vmx

```
vim-cmd vmsvc/getallvms | grep -i <name> 
vim-cmd vmsvc/reload <id>
```

![](../images/img-manual/Screenshot_937.png)

+ Bật VM và kiểm tra

```
cat /proc/cpuinfo | egrep -c "vmx|svm"
```

Nếu OUTPUT câu lệnh trên >0 thì đã enable vmx OK

![](../images/img-manual/Screenshot_938.png)

<a name="controller"></a>
## 4. Cài đặt node controller

### 4.1. Setup cơ bản

**Cấu hình IP**

```
hostnamectl set-hostname controller

echo "Setup IP ens160"
nmcli c modify ens160 ipv4.addresses 10.10.10.118/24
nmcli c modify ens160 ipv4.gateway 10.10.10.1
nmcli c modify ens160 ipv4.dns 8.8.8.8
nmcli c modify ens160 ipv4.method manual
nmcli con mod ens160 connection.autoconnect yes

echo "Setup IP ens192"
nmcli c modify ens192 ipv4.addresses 10.10.13.118/24
nmcli c modify ens192 ipv4.method manual
nmcli con mod ens192 connection.autoconnect yes

echo "Setup IP ens224"
nmcli c modify ens224 ipv4.addresses 10.10.12.118/24
nmcli c modify ens224 ipv4.method manual
nmcli con mod ens224 connection.autoconnect yes

echo "Setup IP ens256"
nmcli c modify ens256 ipv4.addresses 10.10.11.118/24
nmcli c modify ens256 ipv4.method manual
nmcli con mod ens256 connection.autoconnect yes

sudo systemctl disable firewalld
sudo systemctl stop firewalld
sudo systemctl disable NetworkManager
sudo systemctl stop NetworkManager
sudo systemctl enable network
sudo systemctl start network
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```

![](../images/img-manual/Screenshot_939.png)

**Cấu hình các mode sysctl**

```
echo 'net.ipv4.conf.all.arp_ignore = 1'  >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.arp_announce = 2'  >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.rp_filter = 2'  >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_be_liberal = 1'  >> /etc/sysctl.conf

cat << EOF >> /etc/sysctl.conf
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.tcp_keepalive_time = 6
net.ipv4.tcp_keepalive_intvl = 3
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
EOF
```

Kiểm tra mode sysctl 

```
sysctl -p
```

**Khai báo repo mariadb và update***

```
echo '[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1' >> /etc/yum.repos.d/MariaDB.repo
yum -y update
```

**Khai báo file hosts các node**

```
echo "10.10.10.118 controller" >> /etc/hosts
echo "10.10.10.119 compute01" >> /etc/hosts
echo "10.10.10.117 compute02" >> /etc/hosts
```

**Tạo SSH key và coppy sang các node compute**


```
ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -P ""
ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa.pub root@controller
ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa.pub root@compute01
ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa.pub root@compute02
scp /root/.ssh/id_rsa root@compute01:/root/.ssh/
scp /root/.ssh/id_rsa root@compute02:/root/.ssh/
```

Đứng từ controller ssh sang node compute không cần nhập password


![](../images/img-manual/Screenshot_940.png)

**Cài đặt các gói cần thiết**

```
yum -y install centos-release-openstack-queens
yum -y install crudini wget vim
yum -y install python-openstackclient openstack-selinux python2-PyMySQL
```

### 4.2. Cài đặt và cấu hình NTP

```
yum -y install chrony
sed -i 's/server 0.centos.pool.ntp.org iburst/ \
server 1.vn.pool.ntp.org iburst \
server 0.asia.pool.ntp.org iburst \
server 3.asia.pool.ntp.org iburst/g' /etc/chrony.conf
sed -i 's/server 1.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/server 2.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/server 3.centos.pool.ntp.org iburst/#/g' /etc/chrony.conf
sed -i 's/#allow 192.168.0.0\/16/allow 10.10.10.0\/24/g' /etc/chrony.conf
```

Đồng bộ thời gian

```
systemctl enable chronyd.service
systemctl start chronyd.service
chronyc sources
```

![](../images/img-manual/Screenshot_941.png)

### 4.3. Cài đặt và cấu hình memcache

+ Cài đặt

```
yum install -y memcached
sed -i "s/-l 127.0.0.1,::1/-l 10.10.10.118/g" /etc/sysconfig/memcached
```
+ Restart service

```
systemctl enable memcached.service
systemctl restart memcached.service
```

### 4.4. Cài đặt và cấu hình MySQL

+ Cài đặt

```
yum install -y mariadb mariadb-server python2-PyMySQL
```
+ Cấu hình

Coppy lại file cấu hình gốc

```
cp /etc/my.cnf.d/server.cnf /etc/my.cnf.d/server.cnf.orig
rm -rf /etc/my.cnf.d/server.cnf
```

Config file cấu hình mới

```
cat << EOF > /etc/my.cnf.d/openstack.cnf
[mysqld]
bind-address = 10.10.10.118
default-storage-engine = innodb
innodb_file_per_table
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF
```

+ Restart service

```
systemctl enable mariadb.service
systemctl restart mariadb.service
```

+ Đặt lại password cho user mysql

Lưu ý: Password đủ độ mạnh và tránh ký tự đặc biệt ở cuối như #,@

```
mysql_secure_installation
```

![](../images/img-manual/Screenshot_942.png)

### 4.5. Cài đặt và cấu hình RabbitMQ 

+ Cài đặt

```
yum -y install rabbitmq-server
```

+ Cấu hình rabbitmq  

```
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
rabbitmq-plugins enable rabbitmq_management
systemctl restart rabbitmq-server
curl -O http://localhost:15672/cli/rabbitmqadmin
chmod a+x rabbitmqadmin
mv rabbitmqadmin /usr/sbin/
rabbitmqadmin list users
```

+ Cấu hình trên node controller 

```
rabbitmqctl add_user openstack Welcome123
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
rabbitmqctl set_user_tags openstack administrator
```

### 4.6. Cài đặt keystone

+ Tạo db

```
mysql -u root -pWelcome123
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'Welcome123';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'Welcome123';
exit
```

+ Cài packages

```
yum install openstack-keystone httpd mod_wsgi -y
```

+ Cấu hình bind port

```
cp /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
sed -i -e 's/VirtualHost \*/VirtualHost 10.10.10.118/g' /etc/httpd/conf.d/wsgi-keystone.conf
sed -i -e 's/Listen 5000/Listen 10.10.10.118:5000/g' /etc/httpd/conf.d/wsgi-keystone.conf
sed -i -e 's/Listen 35357/Listen 10.10.10.118:35357/g' /etc/httpd/conf.d/wsgi-keystone.conf
sed -i -e 's/^Listen.*/Listen 10.10.10.118:80/g' /etc/httpd/conf/httpd.conf
```

+ Cấu hình keystone
 
```
cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.org
rm -rf /etc/keystone/keystone.conf
```

```
cat << EOF >> /etc/keystone/keystone.conf
[DEFAULT]
[assignment]
[auth]
[cache]
[catalog]
[cors]
[credential]
[database]
connection = mysql+pymysql://keystone:Welcome123@10.10.10.118/keystone
[domain_config]
[endpoint_filter]
[endpoint_policy]
[eventlet_server]
[federation]
[fernet_tokens]
[healthcheck]
[identity]
[identity_mapping]
[ldap]
[matchmaker_redis]
[memcache]
[oauth1]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[paste_deploy]
[policy]
[profiler]
[resource]
[revoke]
[role]
[saml]
[security_compliance]
[shadow_users]
[signing]
[token]
provider = fernet
[tokenless_auth]
[trust]
EOF
```

+ Phân quyền file cấu hình

```
chown root:keystone /etc/keystone/keystone.conf
```

+ Sync db

```
su -s /bin/sh -c "keystone-manage db_sync" keystone
```

+ Set up fernet key

```
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
```

+ Bootstrap keystone

```
keystone-manage bootstrap --bootstrap-password Welcome123 \
  --bootstrap-admin-url http://10.10.10.118:5000/v3/ \
  --bootstrap-internal-url http://10.10.10.118:5000/v3/ \
  --bootstrap-public-url http://10.10.10.118:5000/v3/ \
  --bootstrap-region-id RegionOne
```

+ Enable và start httpd

```
systemctl enable httpd.service
systemctl restart httpd.service
```

+ Export biến môi trường

```
export OS_USERNAME=admin
export OS_PASSWORD=Welcome123
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://10.10.10.118:35357/v3
export OS_IDENTITY_API_VERSION=3
```
+ Tạo domain 

```
openstack domain create --description "An Example Domain" example
openstack project create --domain default --description "Service Project" service
```

+ Tạo project và user

```
openstack project create --domain default  --description "Demo Project" demo
openstack user create --domain default --password Welcome123 demo
```

+ Tạo role và gắn role

```
openstack role create user
openstack role add --project demo --user demo user
```

+ Unset 2 biến môi trường
 
```
unset OS_AUTH_URL OS_PASSWORD
```

+ Tạo token

```
openstack --os-auth-url http://172.16.4.125:35357/v3 \
  --os-project-domain-name Default --os-user-domain-name Default \
  --os-project-name admin --os-username admin token issue
```

+ Tạo file xác thực 

```
cat << EOF >> admin-openrc
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=Welcome123
export OS_AUTH_URL=http://10.10.10.118:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
```

```
cat << EOF >> demo-openrc
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=Welcome123
export OS_AUTH_URL=http://10.10.10.118:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
```

+ Kiểm tra cấu hình keystone

```
 . admin-openrc
openstack token issue
```

Kết quả hiện ra bảng token

![](../images/img-manual/Screenshot_943.png)

### 4.6. Cài đặt và cấu hình glance 

+ Tạo db

```
mysql -u root -pWelcome123
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'Welcome123';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'Welcome123';
exit
```

+ Tạo user
 
```
openstack user create --domain default --password Welcome123 glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
```

+ Tạo endpoint

```
openstack endpoint create --region RegionOne image public http://10.10.10.118:9292
openstack endpoint create --region RegionOne image admin http://10.10.10.118:9292
openstack endpoint create --region RegionOne image internal http://10.10.10.118:9292
```

+ Cài packages
 
```
yum install -y openstack-glance
```

+ Cấu hình glance api

```
cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf.org 
rm -rf /etc/glance/glance-api.conf
```
```
cat << EOF >> /etc/glance/glance-api.conf
[DEFAULT]
bind_host = 10.10.10.118
registry_host = 10.10.10.118
[cors]
[database]
connection = mysql+pymysql://glance:Welcome123@10.10.10.118/glance
[glance_store]
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images/
[image_format]
[keystone_authtoken]
auth_uri = http://10.10.10.118:5000
auth_url = http://10.10.10.118:5000
memcached_servers = 10.10.10.118:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = Welcome123
[matchmaker_redis]
[oslo_concurrency]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[paste_deploy]
flavor = keystone
[profiler]
[store_type_location_strategy]
[task]
[taskflow_executor]
EOF
```

+ Cấu hình glance registry

```
cp /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.org
rm -rf /etc/glance/glance-registry.conf
```

```
cat << EOF >> /etc/glance/glance-registry.conf
[DEFAULT]
bind_host = 10.10.10.118
[database]
connection = mysql+pymysql://glance:Welcome123@10.10.10.118/glance
[keystone_authtoken]
auth_uri = http://10.10.10.118:5000
auth_url = http://10.10.10.118:5000
memcached_servers = 10.10.10.118
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = Welcome123
[matchmaker_redis]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_policy]
[paste_deploy]
flavor = keystone
[profiler]
EOF
```

+ Phân quyền file cấu hình
 
```
chown root:glance /etc/glance/glance-api.conf
chown root:glance /etc/glance/glance-registry.conf
```

+ Sync db

```
su -s /bin/sh -c "glance-manage db_sync" glance
```

+ Enable và start dịch vụ 

```
systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service
```

+ Download và upload image test cirros
 
```
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
openstack image create "cirros" \
  --file cirros-0.3.5-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public
```

Sau khi tạo images, mặc định image sẽ được đưa vào thư mục /var/lib/glance/images


![](../images/img-manual/Screenshot_944.png)

### 4.7. Cài đặt và cấu hình nova

+ Tạo database nova

```
mysql -u root -pWelcome123
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'Welcome123';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'Welcome123';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'Welcome123';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'Welcome123';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'Welcome123';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'Welcome123';
exit
```

+ Tạo user và endpoint

```
openstack user create --domain default --password Welcome123 nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
```

```
openstack endpoint create --region RegionOne compute public http://10.10.10.118:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://10.10.10.118:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://10.10.10.118:8774/v2.1
```

```
openstack user create --domain default --password Welcome123 placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
```

```
openstack endpoint create --region RegionOne placement public http://10.10.10.118:8778
openstack endpoint create --region RegionOne placement admin http://10.10.10.118:8778
openstack endpoint create --region RegionOne placement internal http://10.10.10.118:8778
```

+ Tải packages

```
yum install -y openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api
```

+ Cấu hình nova

```
cp /etc/nova/nova.conf /etc/nova/nova.conf.org 
rm -rf /etc/nova/nova.conf
```

```
cat << EOF >> /etc/nova/nova.conf
[DEFAULT]
my_ip = 10.10.10.118
enabled_apis = osapi_compute,metadata
use_neutron = True
osapi_compute_listen=10.10.10.118
metadata_host=10.10.10.118
metadata_listen=10.10.10.118
metadata_listen_port=8775
firewall_driver = nova.virt.firewall.NoopFirewallDriver
transport_url = rabbit://openstack:Welcome123@10.10.10.118:5672
[api]
auth_strategy = keystone
[api_database]
connection = mysql+pymysql://nova:Welcome123@10.10.10.118/nova_api
[barbican]
[cache]
backend = oslo_cache.memcache_pool
enabled = true
memcache_servers = 10.10.10.118:11211
[cells]
[cinder]
[compute]
[conductor]
[console]
[consoleauth]
[cors]
[crypto]
[database]
connection = mysql+pymysql://nova:Welcome123@10.10.10.118/nova
[devices]
[ephemeral_storage_encryption]
[filter_scheduler]
[glance]
api_servers = http://10.10.10.118:9292
[guestfs]
[healthcheck]
[hyperv]
[ironic]
[key_manager]
[keystone]
[keystone_authtoken]
auth_url = http://10.10.10.118:5000/v3
memcached_servers = 10.10.10.118:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = nova
password = Welcome123
[libvirt]
[matchmaker_redis]
[metrics]
[mks]
[neutron]
[notifications]
[osapi_v21]
[oslo_concurrency]
lock_path = /var/lib/nova/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
rabbit_ha_queues = true
rabbit_retry_interval = 1
rabbit_retry_backoff = 2
amqp_durable_queues= true
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[pci]
[placement]
os_region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://10.10.10.118:5000/v3
username = placement
password = Welcome123
[quota]
[rdp]
[remote_debug]
[scheduler]
discover_hosts_in_cells_interval = 300
[serial_console]
[service_user]
[spice]
[upgrade_levels]
[vault]
[vendordata_dynamic_auth]
[vmware]
[vnc]
novncproxy_host=10.10.10.118
enabled = true
vncserver_listen = 10.10.10.118
vncserver_proxyclient_address = 10.10.10.118
novncproxy_base_url = http://10.10.10.118:6080/vnc_auto.html
[workarounds]
[wsgi]
[xenserver]
[xvp]
EOF
```

+ Thêm vào file 00-nova-placement-api.conf 

```
cat << 'EOF' >> /etc/httpd/conf.d/00-nova-placement-api.conf

<Directory /usr/bin>
   <IfVersion >= 2.4>
      Require all granted
   </IfVersion>
   <IfVersion < 2.4>
      Order allow,deny
      Allow from all
   </IfVersion>
</Directory>
EOF
```

+ Cấu hình bind port cho nova-placement
 
```
sed -i -e 's/VirtualHost \*/VirtualHost 10.10.10.118/g' /etc/httpd/conf.d/00-nova-placement-api.conf
sed -i -e 's/Listen 8778/Listen 10.10.10.118:8778/g' /etc/httpd/conf.d/00-nova-placement-api.conf
```

+ Restart httpd

```
systemctl restart httpd
```

+ Sync db
 
```
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
```

Lưu ý: Bỏ qua cảnh báo `Warning`

+ Enable và start service

```
systemctl enable openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-consoleauth.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-consoleauth.service openstack-nova-conductor.service openstack-nova-novncproxy.service
```

+ Kiểm tra lại dịch vụ

```
openstack compute service list
```

![](../images/img-manual/Screenshot_945.png)

### 4.8. Cài đặt và cấu hình neutron

+ Tạo database neutron
 
```
mysql -u root -pWelcome123
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'Welcome123';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'Welcome123';
exit
```

+ Tạo user, endpoint trên 1 node

```
openstack user create --domain default --password Welcome123 neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
```

```
openstack endpoint create --region RegionOne network public http://10.10.10.118:9696
openstack endpoint create --region RegionOne network internal http://10.10.10.118:9696
openstack endpoint create --region RegionOne network admin http://10.10.10.118:9696
```

+ Cài packages

```
yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables -y
```

+ Cấu hình neutron
 
Bài lab này sử dụng mô hình mạng provider (flat) sử dụng linuxbridge
DHCP agent và metadata agent được chạy trên node compute

```
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.org
rm -rf /etc/neutron/neutron.conf
```

```
cat << EOF >> /etc/neutron/neutron.conf
[DEFAULT]
bind_host = 10.10.10.118
core_plugin = ml2
service_plugins = router
transport_url = rabbit://openstack:Welcome123@10.10.10.118:5672
auth_strategy = keystone
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true
allow_overlapping_ips = True
dhcp_agents_per_network = 2
[agent]
[cors]
[database]
connection = mysql+pymysql://neutron:Welcome123@10.10.10.118/neutron
[keystone_authtoken]
auth_uri = http://10.10.10.118:5000
auth_url = http://10.10.10.118:35357
memcached_servers = 10.10.10.118:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = Welcome123
[matchmaker_redis]
[nova]
auth_url = http://10.10.10.118:35357
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = Welcome123
[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
rabbit_retry_interval = 1
rabbit_retry_backoff = 2
amqp_durable_queues = true
rabbit_ha_queues = true
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[quotas]
[ssl]
EOF
```

+ Cấu hình file ml2

```
cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.org
rm -rf /etc/neutron/plugins/ml2/ml2_conf.ini
```

```
cat << EOF >> /etc/neutron/plugins/ml2/ml2_conf.ini
[DEFAULT]
[l2pop]
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security
[ml2_type_flat]
[ml2_type_geneve]
[ml2_type_gre]
[ml2_type_vlan]
network_vlan_ranges = provider
[ml2_type_vxlan]
vni_ranges = 1:1000
[securitygroup]
enable_ipset = True
EOF
```

+ Cấu hình file LB agent
 
```
cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.org 
rm -rf /etc/neutron/plugins/ml2/linuxbridge_agent.ini
```

Lưu ý khi chạy đoạn ở dưới chú ý 2 tham số: 

physical_interface_mappings = provider:ens256 (interface name provider)

local_ip = 10.10.12.118(ip dải datavm controller)

```
cat << EOF >> /etc/neutron/plugins/ml2/linuxbridge_agent.ini
[DEFAULT]
[agent]
[linux_bridge]
physical_interface_mappings = provider:ens256
[network_log]
[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
[vxlan]
enable_vxlan = true
local_ip = 10.10.12.118
l2_population = true
EOF
```

+ Cấu hình trên file l3 agent

```
cp /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.org
rm -rf /etc/neutron/l3_agent.ini
```

```
cat << EOF >> /etc/neutron/l3_agent.ini
[DEFAULT]
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
[agent]
[ovs]
EOF
```

+ Chỉnh sửa file /etc/nova/nova.conf 
 
```
vi /etc/nova/nova.conf
``` 

```
[neutron]
url = http://10.10.10.118:9696
auth_url = http://10.10.10.118:35357
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = Welcome123
service_metadata_proxy = true
metadata_proxy_shared_secret = Welcome123
```

+ Restart lại service nova-api
 
```
systemctl restart openstack-nova-api.service
```

+ Phân quyền file cấu hình
	
```
chown -R root:neutron /etc/neutron/
```

+ Tạo liên kết

```
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
```

+ Sync db (bỏ qua các cảnh báo Warning)
 
```
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
```

+ Enable và start dịch vụ 

```
systemctl restart openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-consoleauth.service openstack-nova-conductor.service openstack-nova-novncproxy.service
```

```
systemctl enable neutron-server.service neutron-linuxbridge-agent.service neutron-l3-agent.service
systemctl start neutron-server.service neutron-linuxbridge-agent.service neutron-l3-agent.service
```


### 4.8. Cài đặt và cấu hình horizon

+ Tải packages

```
yum install openstack-dashboard -y
```

+ Tạo file direct
 
```
filehtml=/var/www/html/index.html
touch $filehtml
cat << EOF >> $filehtml
<html>
<head>
<META HTTP-EQUIV="Refresh" Content="0.5; URL=http://10.10.10.118/dashboard">
</head>
<body>
<center> <h1>Redirecting to OpenStack Dashboard</h1> </center>
</body>
</html>
EOF
```

+ Backup cấu hình
 
```
cp /etc/openstack-dashboard/local_settings /etc/openstack-dashboard/local_settings.org
```

+ Thay đổi cấu hình trong file /etc/openstack-dashboard/local_settings
 
```
ALLOWED_HOSTS = ['*',]
OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 2,
}
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'
```

+ Lưu ý thêm SESSION_ENGINE vào trên dòng CACHE như bên dưới
 
```
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
CACHES = {
    'default': {
         'BACKEND':'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': ['10.10.10.118:11211',],
    }
}
OPENSTACK_HOST = "10.10.10.118"
OPENSTACK_KEYSTONE_URL = "http://10.10.10.118:5000/v3"
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"
```

+ Lưu ý: Nếu chỉ sử dụng provider, chỉnh sửa các thông số sau

```
OPENSTACK_NEUTRON_NETWORK = {
    'enable_router': False,
    'enable_quotas': False,
    'enable_ipv6': False,
    'enable_distributed_router': False,
    'enable_ha_router': False,
    'enable_fip_topology_check': False,
}
```

```
TIME_ZONE = "Asia/Ho_Chi_Minh"
```

+ Thêm vào file /etc/httpd/conf.d/openstack-dashboard.conf
 
```
echo "WSGIApplicationGroup %{GLOBAL}" >> /etc/httpd/conf.d/openstack-dashboard.conf
```

+ Restart lại httpd
 
```
systemctl restart httpd.service memcached.service
```

### 4.9. Cài đặt và cấu hình Cinder

Mô hình sử dụng một phân vùng riêng để lưu các volume của máy ảo.

![](../images/img-manual/Screenshot_946.png)

+ Tạo database cinder
 
```
mysql -u root -pWelcome123
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' \
  IDENTIFIED BY 'Welcome123';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' \
  IDENTIFIED BY 'Welcome123';  
exit
```

+ Tạo service, user và endpoint

```
openstack user create --domain default --password Welcome123 cinder
openstack role add --project service --user cinder admin
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
```
 
``` 
openstack endpoint create --region RegionOne volumev2 public http://10.10.10.118:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://10.10.10.118:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://10.10.10.118:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 public http://10.10.10.118:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 internal http://10.10.10.118:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 admin http://10.10.10.118:8776/v3/%\(project_id\)s
```

+ Tải package
 
```
yum install openstack-cinder targetcli python-keystone -y
```

+ Cài đặt và cấu hình cinder volume với LVM
 
```
yum install -y lvm2
```

+ Khởi động dịch vụ LVM và cho phép khởi động cùng hệ thống.
 
```
systemctl enable lvm2-lvmetad.service
systemctl start lvm2-lvmetad.service
```

+ Tạo LVM physical volume /dev/sdb
 
```
pvcreate /dev/sdb
```

+ Tạo LVM volume group `cinder-volumes`
 
```
vgcreate cinder-volumes /dev/sdb
```

+ Sửa file `/etc/lvm/lvm.conf`, để LVM chỉ scan ổ sdb cho block storage

```
devices {
...
filter = [ "a/sdb/", "r/.*/"]
```

+ Sửa cấu hình cinder

```
cp /etc/cinder/cinder.conf /etc/cinder/cinder.conf.bak 
rm -rf /etc/cinder/cinder.conf
```

```
cat << EOF >> /etc/cinder/cinder.conf
[DEFAULT]
my_ip = 10.10.10.118
transport_url = rabbit://openstack:Welcome123@10.10.10.118:5672
auth_strategy = keystone
osapi_volume_listen = 10.10.10.118
enabled_backends = lvm
[backend]
[backend_defaults]
[barbican]
[brcd_fabric_example]
[cisco_fabric_example]
[coordination]
[cors]
[database]
connection = mysql+pymysql://cinder:Welcome123@10.10.10.118/cinder
[fc-zone-manager]
[healthcheck]
[key_manager]
[keystone_authtoken]
auth_uri = http://10.10.10.118:5000
auth_url = http://10.10.10.118:35357
memcached_servers = 10.10.10.118:11211
auth_type = password
project_domain_id = default
user_domain_id = default
project_name = service
username = cinder
password = Welcome123
[matchmaker_redis]
[nova]
[oslo_concurrency]
lock_path = /var/lib/cinder/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
rabbit_retry_interval = 1
rabbit_retry_backoff = 2
amqp_durable_queues = true
rabbit_ha_queues = true
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[oslo_reports]
[oslo_versionedobjects]
[profiler]
[service_user]
[ssl]
[vault]
[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = lioadm
volume_backend_name = lvm
EOF
```

+ Phân quyền file cấu hình
 
```
chown root:cinder /etc/cinder/cinder.conf
```

+ Sync db

```
su -s /bin/sh -c "cinder-manage db sync" cinder
```

+ Chỉnh sửa file /etc/nova/nova.conf

```
[cinder]
os_region_name = RegionOne
```

+ Restart dịch vụ nova api 

```
systemctl restart openstack-nova-api.service
```

+ Enable va start dịch vụ

```
systemctl enable openstack-cinder-api.service openstack-cinder-volume.service openstack-cinder-scheduler.service
systemctl restart openstack-cinder-api.service openstack-cinder-volume.service openstack-cinder-scheduler.service
```

<a name="compute"></a>
## 5. Cài đặt node compute

### 5.1. Setup cơ bản

**Cấu hình IP**

```
hostnamectl set-hostname controller

echo "Setup IP ens160"
nmcli c modify ens160 ipv4.addresses 10.10.10.119/24
nmcli c modify ens160 ipv4.gateway 10.10.10.1
nmcli c modify ens160 ipv4.dns 8.8.8.8
nmcli c modify ens160 ipv4.method manual
nmcli con mod ens160 connection.autoconnect yes

echo "Setup IP ens192"
nmcli c modify ens192 ipv4.addresses 10.10.13.119/24
nmcli c modify ens192 ipv4.method manual
nmcli con mod ens192 connection.autoconnect yes

echo "Setup IP ens224"
nmcli c modify ens224 ipv4.addresses 10.10.12.119/24
nmcli c modify ens224 ipv4.method manual
nmcli con mod ens224 connection.autoconnect yes

echo "Setup IP ens256"
nmcli c modify ens256 ipv4.addresses 10.10.11.119/24
nmcli c modify ens256 ipv4.method manual
nmcli con mod ens256 connection.autoconnect yes

sudo systemctl disable firewalld
sudo systemctl stop firewalld
sudo systemctl disable NetworkManager
sudo systemctl stop NetworkManager
sudo systemctl enable network
sudo systemctl start network
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```

![](../images/img-manual/Screenshot_947.png)

**Cấu hình các mode sysctl**

```
echo 'net.ipv4.conf.all.arp_ignore = 1'  >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.arp_announce = 2'  >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.rp_filter = 2'  >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_be_liberal = 1'  >> /etc/sysctl.conf
```

```
cat << EOF >> /etc/sysctl.conf
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.tcp_keepalive_time = 6
net.ipv4.tcp_keepalive_intvl = 3
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
EOF
```
```
sysctl -p
```

**update**

```
yum -y update
```

**Khai bao file hosts**

```
echo "10.10.10.118 controller" >> /etc/hosts
echo "10.10.10.119 compute01" >> /etc/hosts
echo "10.10.10.117 compute02" >> /etc/hosts
```

**Cai dat cac goi can thiet **

```
yum -y install centos-release-openstack-queens
yum -y install crudini wget vim
yum -y install python-openstackclient openstack-selinux python2-PyMySQL
```

**Cài đặt và cấu hình NTP**

```
yum -y install chrony
VIP_MGNT_IP='10.10.10.118'
sed -i '/server/d' /etc/chrony.conf
echo "server $VIP_MGNT_IP iburst" >> /etc/chrony.conf
systemctl enable chronyd.service
systemctl restart chronyd.service
chronyc sources
```

![](../images/img-manual/Screenshot_948.png)

**Chinh sua file /etc/yum.repos.d/CentOS-QEMU-EV.repo**

```
sed -i 's|baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\/virt\/$basearch\/kvm-common\/|baseurl=http:\/\/mirror.centos.org\/centos\/7\/virt\/x86_64\/kvm-common\/|g' /etc/yum.repos.d/CentOS-QEMU-EV.repo
```

### 5.2. Cài đặt nova

+ Cài đặt

```
yum install openstack-nova-compute libvirt-client -y
```

+ Cấu hình nova

```
cp /etc/nova/nova.conf  /etc/nova/nova.conf.org
rm -rf /etc/nova/nova.conf
```

```
cat << EOF >> /etc/nova/nova.conf 
[DEFAULT]
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:Welcome123@10.10.10.118:5672
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver
[api]
auth_strategy = keystone
[api_database]
[barbican]
[cache]
[cells]
[cinder]
[compute]
[conductor]
[console]
[consoleauth]
[cors]
[crypto]
[database]
[devices]
[ephemeral_storage_encryption]
[filter_scheduler]
[glance]
api_servers = http://10.10.10.118:9292
[guestfs]
[healthcheck]
[hyperv]
[ironic]
[key_manager]
[keystone]
[keystone_authtoken]
auth_url = http://10.10.10.118:5000/v3
memcached_servers = 10.10.10.118:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = nova
password = Welcome123
[libvirt]
virt_type = qemu
[matchmaker_redis]
[metrics]
[mks]
[neutron]
url = http://10.10.10.118:9696
auth_url = http://10.10.10.118:35357
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = Welcome123
[notifications]
[osapi_v21]
[oslo_concurrency]
lock_path = /var/lib/nova/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
rabbit_ha_queues = true
rabbit_retry_interval = 1
rabbit_retry_backoff = 2
amqp_durable_queues= true
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[pci]
[placement]
os_region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://10.10.10.118:5000/v3
username = placement
password = Welcome123
[quota]
[rdp]
[remote_debug]
[scheduler]
discover_hosts_in_cells_interval = 300
[serial_console]
[service_user]
[spice]
[upgrade_levels]
[vault]
[vendordata_dynamic_auth]
[vmware]
[vnc]
enabled = True
server_listen = 0.0.0.0
server_proxyclient_address = 10.10.10.119
novncproxy_base_url = http://10.10.10.118:6080/vnc_auto.html
[workarounds]
[wsgi]
[xenserver]
[xvp]
EOF
```

+ Phan quyen

```
chown root:nova /etc/nova/nova.conf
```

+ Enable, start service

```
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl restart libvirtd.service openstack-nova-compute.service
```

### 5.3. Cài đặt neutron

+ Cài đặt

```
yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables -y
```

+ Cấu hình neutron

```
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.org 
rm -rf /etc/neutron/neutron.conf
```

```
cat << EOF >> /etc/neutron/neutron.conf
[DEFAULT]
transport_url = rabbit://openstack:Welcome123@10.10.10.118:5672
auth_strategy = keystone
[agent]
[cors]
[database]
[keystone_authtoken]
auth_uri = http://10.10.10.118:5000
auth_url = http://10.10.10.118:35357
memcached_servers = 10.10.10.118:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = Welcome123
[matchmaker_redis]
[nova]
[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
rabbit_ha_queues = true
rabbit_retry_interval = 1
rabbit_retry_backoff = 2
amqp_durable_queues= true
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[quotas]
[ssl]
EOF
```

+ Cấu hình file LB agent

Lưu ý khi chạy đoạn ở dưới chú ý 2 tham số:

physical_interface_mappings = provider:ens256 (interface name provider)

local_ip = 10.10.12.119(ip dải datavm compute)

```
cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.org 
rm -rf /etc/neutron/plugins/ml2/linuxbridge_agent.ini
```

```
cat << EOF >> /etc/neutron/plugins/ml2/linuxbridge_agent.ini
[DEFAULT]
[agent]
[linux_bridge]
physical_interface_mappings = provider:ens256
[network_log]
[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
[vxlan]
enable_vxlan = true
local_ip = 10.10.12.119
l2_population = true
EOF
```

+ Cấu hình dhcp agent

```
cp /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.org
rm -rf /etc/neutron/dhcp_agent.ini
```

```
cat << EOF >> /etc/neutron/dhcp_agent.ini
[DEFAULT]
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true
force_metadata = True
[agent]
[ovs]
EOF
```

+ Cấu hình metadata agent

```
cp /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.org 
rm -rf /etc/neutron/metadata_agent.ini
```

```
cat << EOF >> /etc/neutron/metadata_agent.ini
[DEFAULT]
nova_metadata_host = 10.10.10.118
metadata_proxy_shared_secret = Welcome123
[agent]
[cache]
EOF
```

+ Phân quyền

```
chown root:neutron /etc/neutron/metadata_agent.ini /etc/neutron/neutron.conf /etc/neutron/dhcp_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini
```


+ Restart service nova

```
systemctl restart libvirtd.service openstack-nova-compute
```

+ Enable, start  service nova

```
systemctl enable neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
systemctl restart neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
```

Cấu hình tương tự Compute02

<a name="dashboard"></a>
## 6. Truy cập dashboard horizon

### 6.1. Login

```
http://10.10.10.118/
```

![](../images/img-manual/Screenshot_949.png)

Login thành công

![](../images/img-manual/Screenshot_950.png)

### 6.2. Tạo flavor

```
openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 0 m1.nano
openstack flavor create --id 1 --vcpus 1 --ram 1024 --disk 0 m1.tiny
openstack flavor create --id 2 --vcpus 2 --ram 2408 --disk 0 m1.small
```

![](../images/img-manual/Screenshot_951.png)


### 6.3. Mở security group

### 6.4. Tạo network

### 6.5. Tạo VM

