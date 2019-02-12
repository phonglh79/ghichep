# Ghi chép lại các bước cài đặt manual Openstack Queen CentOS 7 trên môi trường VMware ESXi 6.0.0

### Mục lục

[1. Mô hình triển khai](#mohinh)<br>
[2. IP Planning](#planning)<br>
[3. Thiết lập ban đầu](#thietlap)<br>
[4. Cài đặt node controller](#controller)<br>

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

yum -y install rabbitmq-server

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

### 4.6. Cài đặt project keystone

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

cp /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
sed -i -e 's/VirtualHost \*/VirtualHost 10.10.10.118/g' /etc/httpd/conf.d/wsgi-keystone.conf
sed -i -e 's/Listen 5000/Listen 10.10.10.118:5000/g' /etc/httpd/conf.d/wsgi-keystone.conf
sed -i -e 's/Listen 35357/Listen 10.10.10.118:35357/g' /etc/httpd/conf.d/wsgi-keystone.conf
sed -i -e 's/^Listen.*/Listen 10.10.10.118:80/g' /etc/httpd/conf/httpd.conf

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

