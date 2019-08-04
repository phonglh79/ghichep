# Ghi chép lại các bước cài đặt multiple Openstack Queen CentOS 7 trên môi trường VMware ESXi 6.0.0

### Mục lục

[1. Mô hình triển khai](#mohinh)<br>
[2. IP Planning](#planning)<br>
[3. Cài đặt 2 cụm Openstack độc lập](#setup)<br>
[4. Config Region](#region)<br>

<a name="mohinh"></a>
## 1. Mô hình triển khai

![](../images/img-multipe-region/topt-multipe-region.png)

<a name="planning"></a>
## 2. IP Planning

Hình ảnh ở dưới thể hiện phân hoạch địa chỉ IP và cấu hình tối thiểu cho các node cài đặt Openstack.

![](../images/img-multipe-region/Screenshot_119.png)

<a name="setup"></a>
## 3. Cài đặt 2 cụm Openstack độc lập

Có thể lựa chọn cài manual [tại đây](https://github.com/domanhduy/ghichep/blob/master/DuyDM/Openstack/install-openstack/docs/manual.md)

hoặc có thể cài theo script [tại đây](https://github.com/domanhduy/openstack-tools/blob/master/docs/openstack-queens-CentOS7-scripts.md)

![](../images/img-multipe-region/Screenshot_120.png)

<a name="region"></a>

Test tạo máy ảo OK

![](../images/img-multipe-region/Screenshot_121.png)

## 4. Config Region

Mặc định khi cài xong một cụm Openstack hệ thống sẽ nhận đó là `RegionOne`, ở bài lab này để cụm `10.10.10.117` là region 1 nên việc chỉnh sửa config thực hiện trên cụm `10.10.10.119` để trỏ về Region 1.

Cụm `10.10.10.119` chia sẻ 2 dịch vụ `keystone, horizon` với `RegionOne`.

2 cụm sử dụng chung database keystone ở Region 1, các service glance, neutron, nova, cinder ở node nào chạy database ở node đó.

### 4.1. Thực hiện config trên node CTL ở Region 1 10.10.10.117

- Tạo mới Region

**Lưu ý: Không source admin-openrc khi chạy keystone-manage** (thoát phiên ssh hiện tại ra và ssh lại phiên mới chạy lệnh tạo region)

```
keystone-manage bootstrap --bootstrap-password Welcome123 \
  --bootstrap-admin-url http://10.10.10.117:5000/v3/ \
  --bootstrap-internal-url http://10.10.10.117:5000/v3/ \
  --bootstrap-public-url http://10.10.10.117:5000/v3/ \
  --bootstrap-region-id RegionTwo
```

- Kiểm tra các Region

```
source admin-openrc
openstack region list
```

![](../images/img-multipe-region/Screenshot_124.png)

- Sau khi sử dụng keystone khởi tạo RegionTwo, keystone trên RegionOne sẽ tự động tạo thêm endpoint identity mới cho việc xác thực.

![](../images/img-multipe-region/Screenshot_125.png)

- Khởi tạo endpoint RegionTwo cho nova, cinder, glance, neutron (Thực hiện trên CTL 10.10.10.117 Region 1)

Các endpoint tạo cho RegionTwo sẽ sử dụng IP CTL 10.10.10.119

Tạo các endpoint

```
openstack endpoint create --region RegionTwo image public http://10.10.10.119:9292
openstack endpoint create --region RegionTwo image admin http://10.10.10.119:9292
openstack endpoint create --region RegionTwo image internal http://10.10.10.119:9292

openstack endpoint create --region RegionTwo network public http://10.10.10.119:9696
openstack endpoint create --region RegionTwo network internal http://10.10.10.119:9696
openstack endpoint create --region RegionTwo network admin http://10.10.10.119:9696

openstack endpoint create --region RegionTwo compute public http://10.10.10.119:8774/v2.1
openstack endpoint create --region RegionTwo compute admin http://10.10.10.119:8774/v2.1
openstack endpoint create --region RegionTwo compute internal http://10.10.10.119:8774/v2.1

openstack endpoint create --region RegionTwo placement public http://10.10.10.119:8778
openstack endpoint create --region RegionTwo placement admin http://10.10.10.119:8778
openstack endpoint create --region RegionTwo placement internal http://10.10.10.119:8778

openstack endpoint create --region RegionTwo volumev2 public http://10.10.10.119:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionTwo volumev2 internal http://10.10.10.119:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionTwo volumev2 admin http://10.10.10.119:8776/v2/%\(project_id\)s

openstack endpoint create --region RegionTwo volumev3 public http://10.10.10.119:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionTwo volumev3 internal http://10.10.10.119:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionTwo volumev3 admin http://10.10.10.119:8776/v3/%\(project_id\)s
```

Kiểm tra

```
openstack endpoint list --region RegionTwo
```

![](../images/img-multipe-region/Screenshot_126.png)


### 4.2. Tạo admin openstack resource trên cho cả 2 node CTL 10.117 và 10.119

```
cat << EOF >> admin-openrc-r2
export OS_REGION_NAME=RegionTwo
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=Welcome123
export OS_AUTH_URL=http://10.10.10.117:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export PS1='[\u@\h \W(admin-openrc)]\$ '
EOF
```

hoặc

```
export OS_REGION_NAME=RegionTwo
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=Welcome123
export OS_AUTH_URL=http://10.10.10.117:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
```

### 4.3. Thực hiện config trên node CTL ở Region 2 10.10.10.119 để chỉnh sửa xác thực keystone node CLT RegionOne 10.10.10.117

**4.3.1. Service glance**

- Truy cập vào node 10.10.10.119

Mục [keystone_authtoken]

`auth_uri`, `auth_url` về CTL10.10.10.117

Chỉnh sửa `region_name` về `RegionTwo`.

**Chỉnh sửa 2 file glance-api.conf và glance-registry.conf**

```
vi /etc/glance/glance-api.conf
```

```
[DEFAULT]
transport_url = rabbit://openstack:Welcome123@10.10.10.119
[cors]
[database]
connection = mysql+pymysql://glance:Welcome123@10.10.10.119/glance
[glance_store]
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images/
[image_format]
[keystone_authtoken]
auth_uri = http://10.10.10.117:5000
auth_url = http://10.10.10.117:5000
memcached_servers = 10.10.10.119:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = Welcome123
region_name = RegionTwo
[matchmaker_redis]
[oslo_concurrency]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
driver = messagingv2
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
```

![](../images/img-multipe-region/Screenshot_127.png)

```
vi /etc/glance/glance-registry.conf
```

```
[DEFAULT]
transport_url = rabbit://openstack:Welcome123@10.10.10.119
[database]
connection = mysql+pymysql://glance:Welcome123@10.10.10.119/glance
[keystone_authtoken]
auth_uri = http://10.10.10.117:5000
auth_url = http://10.10.10.117:5000
memcached_servers = 10.10.10.119:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = Welcome123
region_name = RegionTwo
[matchmaker_redis]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
driver = messagingv2
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_policy]
[paste_deploy]
flavor = keystone
```

![](../images/img-multipe-region/Screenshot_128.png)

- Restart service glance

```
systemctl restart openstack-glance-api.service openstack-glance-registry.service
```

- Kiểm tra trên controller 2 region với điều kiện xác thực admin-openrc-r2

```
source admin-openrc-r2
openstack --debug image list --os-region-name RegionTwo
```

![](../images/img-multipe-region/Screenshot_129.png)

- Upload image mới lên để xem xác thực admin-openrc-r2 có ok hay không (test với ciros)

```
openstack image create "cirrosr2" --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public
```

- Đứng trên node region 1 chạy lệnh kiểm tra image ở region 2

```
openstack image list --os-region-name RegionTwo
```
![](../images/img-multipe-region/Screenshot_130.png)

**Lưu ý**: Đứng ở region nào up thì chỉ xuất hiện image ở region đó.

**4.3.1. Service nova**

Đối với service nova, cần chỉnh sửa lại config trên node ở region 2 `CTL 10.119`, `COM1 10.120`

- Thực hiện trên CTL 10.10.10.119

Chỉnh sửa lại mục các mục `[keystone_authtoken]`, `[neutron]`, `[placement]`, `[cinder]` tại `/etc/nova/nova.conf`

Mục [cinder]:

```
Chỉnh sửa os_region_name về RegionTwo
```

Mục [keystone_authtoken]:

```
auth_url về CTL10.10.10.117
region_name về RegionTwo
```

Mục [neutron]:

```
Chỉnh sửa `auth_url` về CTL 10.10.10.117
region_name về RegionTwo
```

Mục [placement]

```
os_region_name về RegionTwo
auth_url về CTL 10.10.10.117
```

```
[root@controller1 ~]# cat /etc/nova/nova.conf | egrep -v "^#|^$"
[DEFAULT]
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:Welcome123@10.10.10.119
my_ip = 10.10.10.119
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver
osapi_compute_listen = $my_ip
metadata_listen = $my_ip
instance_usage_audit = True
instance_usage_audit_period = hour
notify_on_state_change = vm_and_task_state
[api]
auth_strategy = keystone
[api_database]
connection = mysql+pymysql://nova:Welcome123@10.10.10.119/nova_api
[barbican]
[cache]
[cells]
[cinder]
os_region_name = RegionTwo
[compute]
[conductor]
[console]
[consoleauth]
[cors]
[crypto]
[database]
connection = mysql+pymysql://nova:Welcome123@10.10.10.119/nova
[devices]
[ephemeral_storage_encryption]
[filter_scheduler]
[glance]
api_servers = http://10.10.10.119:9292
[guestfs]
[healthcheck]
[hyperv]
[ironic]
[key_manager]
[keystone]
[keystone_authtoken]
auth_url = http://10.10.10.117:35357
memcached_servers = 10.10.10.119:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = Welcome123
region_name = RegionTwo
[libvirt]
[matchmaker_redis]
[metrics]
[mks]
[neutron]
url = http://10.10.10.119:9696
auth_url = http://10.10.10.117:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionTwo
project_name = service
username = neutron
password = Welcome123
service_metadata_proxy = True
metadata_proxy_shared_secret = Welcome123
[notifications]
[osapi_v21]
[oslo_concurrency]
lock_path = /var/lib/nova/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
driver = messagingv2
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[pci]
[placement]
os_region_name = RegionTwo
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://10.10.10.117:5000/v3
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
vncserver_listen = $my_ip
vncserver_proxyclient_address = $my_ip
novncproxy_host = $my_ip
[workarounds]
[wsgi]
[xenserver]
[xvp]
```

- Restart lại service nova

```
systemctl restart openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-consoleauth.service openstack-nova-conductor.service openstack-nova-novncproxy.service
```

- Kiểm tra

Đứng trên node CTL region 1

```
openstack --debug server list --os-region-name RegionTwo
```

```
openstack compute service list --os-region-name RegionTwo
```

![](../images/img-multipe-region/Screenshot_131.png)

- Thực hiện trên node Compute thuộc region 2 10.10.10.120

Với dịch vụ nova chỉnh sửa /etc/nova/nova.conf tại COM 10.120, chỉnh sửa lại config [cinder], [keystone_authtoken], [neutron], [placement]

Mục [cinder]:
```
Chỉ định sử dụng cinder service của RegionTwo (os_region_name = RegionTwo)
```

Mục [keystone_authtoken]:

```
Chỉnh sửa auth_url về CTL 10.10.10.117
region_name về RegionTwo
```
Mục [neutron]:

```
Chỉnh sửa auth_url về CTL 10.10.10.117
region_name về RegionTwo
```

Mục [placement]:

```
Chỉnh sửa auth_url về CTL 10.10.10.117
Sửa os_region_name về RegionTwo
```

```
[DEFAULT]
enabled_apis = osapi_compute,metadata
my_ip = 10.10.10.120
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver
transport_url = rabbit://openstack:Welcome123@10.10.10.119
instance_usage_audit = True
instance_usage_audit_period = hour
notify_on_state_change = vm_and_task_state
[api]
auth_strategy = keystone
[api_database]
[barbican]
[cache]
[cells]
[cinder]
os_region_name = RegionTwo
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
api_servers = http://10.10.10.119:9292
[guestfs]
[healthcheck]
[hyperv]
[ironic]
[key_manager]
[keystone]
[keystone_authtoken]
auth_url = http://10.10.10.117:5000
memcached_servers = 10.10.10.119:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = Welcome123
region_name = RegionTwo
[libvirt]
virt_type = qemu
[matchmaker_redis]
[metrics]
[mks]
[neutron]
url = http://10.10.10.119:9696
auth_url = http://10.10.10.117:35357
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = Welcome123
region_name = RegionTwo
[notifications]
[osapi_v21]
[oslo_concurrency]
lock_path = /var/lib/nova/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
driver = messagingv2
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[pci]
[placement]
os_region_name = RegionTwo
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://10.10.10.117:5000/v3
username = placement
password = Welcome123
#region_name = RegionTwo
[quota]
[rdp]
[remote_debug]
[scheduler]
[serial_console]
[service_user]
[spice]
[upgrade_levels]
[vault]
[vendordata_dynamic_auth]
[vmware]
[vnc]
enabled = True
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = $my_ip
novncproxy_base_url = http://10.10.10.119:6080/vnc_auto.html
[workarounds]
[wsgi]
[xenserver]
[xvp]
```

- Restart service nova

```
systemctl restart libvirtd.service openstack-nova-compute
```

- Kiểm tra

Kiểm tra log tại Nova Compute 

```
cat /var/log/nova/nova-compute.log | grep 'placement'
```

Nếu xuất hiện log lỗi 

```
2019-07-06 15:16:00.215 15323 ERROR nova.scheduler.client.report [req-a15792f5-d73f-45c3-9af4-9d2385989346 - - - - -] [req-af3f7632-7fd0-4682-93b1-35ccc87ce7b4] Failed to retrieve resource provider tree from placement API for UUID ae7a901c-ff58-476b-87e1-92fb790b44d8. Got 401: {"error": {"message": "The request you have made requires authentication.", "code": 401, "title": "Unauthorized"}}.
```

```
Nếu xuất hiện, kiểm tra config tại nova controller và nova compute, sau đó khởi động os CTL 10.119 và com 10.120 thuộc RegionTwo (nguyên nhân do database hoặc cache)
```

![](../images/img-multipe-region/Screenshot_132.png)


Thực hiện trên node CLT của region 1

```
openstack compute service list --os-region-name RegionTwo
```

![](../images/img-multipe-region/Screenshot_133.png)

**4.3.3. Service cinder**

Thực hiện trên node CTL region 2

Với dịch vụ Cinder, ta sẽ chỉnh sửa các mục [keystone_authtoken] tại /etc/cinder/cinder.conf

Mục [keystone_authtoken]

```
Sửa auth_uri, auth_url về CTL 10.10.10.1117
region_name về RegionTwo
```

```
[DEFAULT]
rpc_backend = rabbit
auth_strategy = keystone
my_ip = 10.10.10.119
control_exchange = cinder
osapi_volume_listen = $my_ip
glance_api_servers = http://10.10.10.119:9292
enabled_backends = lvm
[backend]
[backend_defaults]
[barbican]
[brcd_fabric_example]
[cisco_fabric_example]
[coordination]
[cors]
[database]
connection = mysql+pymysql://cinder:Welcome123@10.10.10.119/cinder
[fc-zone-manager]
[healthcheck]
[key_manager]
[keystone_authtoken]
auth_uri = http://10.10.10.117:5000
auth_url = http://10.10.10.117:5000
memcached_servers = 10.10.10.119:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = cinder
password = Welcome123
region_name = RegionTwo
[matchmaker_redis]
[nova]
[oslo_concurrency]
lock_path = /var/lib/cinder/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
driver = messagingv2
[oslo_messaging_rabbit]
rabbit_host = 10.10.10.119
rabbit_port = 5672
rabbit_userid = openstack
rabbit_password = Welcome123
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
```

- Restart service cinder

```
systemctl restart openstack-cinder-api.service openstack-cinder-volume.service openstack-cinder-scheduler.service
```

- Kiểm tra từ node CTL region 1

```
openstack volume service list --os-region-name RegionTwo
```

![](../images/img-multipe-region/Screenshot_134.png)


**4.3.4. Service neutron**

Với Neutron, ta cần chỉnh sửa lại settings trên CTL 10.10.10.119, COM1 10.10.10.120

Thực hiện trên CTL 10.10.10.119

Chỉnh sửa các mục [keystone_authtoken], [nova] tại /etc/neutron/neutron.conf

Mục [keystone_authtoken]

```
Sửa auth_uri, auth_url về CTL 10.10.10.117
region_name về RegionTwo
```

Mục [nova]

```
auth_url về CTL 10.10.10.117
region_name = RegionTwo
```

```
[DEFAULT]
core_plugin = ml2
service_plugins = router
auth_strategy = keystone
transport_url = rabbit://openstack:Welcome123@10.10.10.119
notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
allow_overlapping_ips = True
dhcp_agents_per_network = 2
nova_metadata_ip = 10.10.10.119
metadata_proxy_shared_secret = Welcome123
[agent]
[cors]
[database]
connection = mysql+pymysql://neutron:Welcome123@10.10.10.119/neutron
[keystone_authtoken]
auth_uri = http://10.10.10.117:5000
auth_url = http://10.10.10.117:5000
memcached_servers = 10.10.10.119:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = Welcome123
region_name = RegionTwo
[matchmaker_redis]
[nova]
auth_url = http://10.10.10.117:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionTwo
project_name = service
username = nova
password = Welcome123
[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
driver = messagingv2
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[quotas]
[ssl]
[linux_bridge]
physical_interface_mappings = provider:eth3
[vxlan]
enable_vxlan = False
[securitygroup]
enable_security_group = True
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
```


- Restart lại service

```
systemctl restart openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-consoleauth.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl restart neutron-server.service neutron-linuxbridge-agent.service neutron-l3-agent.service
```

- Thực hiện trên COM1 10.10.10.120

Chỉnh sửa lại các mục `[keystone_authtoken]` tại /etc/neutron/neutron.conf

```
Sửa auth_uri, auth_url về CTL 10.10.10.117
region_name về RegionTwo
```

```
[DEFAULT]
auth_strategy = keystone
core_plugin = ml2
transport_url = rabbit://openstack:Welcome123@10.10.10.119
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true
[agent]
[cors]
[database]
[keystone_authtoken]
auth_uri = http://10.10.10.117:5000
auth_url = http://10.10.10.117:5000
memcached_servers = 10.10.10.119:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = Welcome123
region_name = RegionTwo
[matchmaker_redis]
[nova]
[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
driver = messagingv2
[oslo_messaging_rabbit]
rabbit_host = 10.10.10.119
rabbit_port = 5672
rabbit_userid = openstack
rabbit_password = Welcome123
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[quotas]
[ssl]
```

- Restart lại service

```
systemctl restart neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
```

- Check ở node CLL 1 region 1

```
openstack network agent list --os-region-name RegionTwo
```

![](../images/img-multipe-region/Screenshot_135.png)

## 4.4. Tạo máy test trên 2 region

![](../images/img-multipe-region/Screenshot_137.png)

## 4.5. Một số lỗi 

- Xuất hiện lỗi tại Node Compute

```
[root@compute01 ~]# cat /var/log/nova/nova-compute.log | grep ERROR

2019-04-11 11:40:05.363 15299 ERROR nova.compute.manager [instance: 5350c69f-24de-4345-9556-0cc92faa3ef2] BuildAbortException: Build of instance 5350c69f-24de-4345-9556-0cc92faa3ef2 aborted: Invalid input received: Invalid image identifier or unable to access requested image. (HTTP 400) (Request-ID: req-1e69aa25-4f63-477d-a8a5-678ebf1bb869)
```

Kiểm tra lại cấu hình cinder:

Tại Controller, có thể thiếu `glance_api_servers` section `[glance_api_servers]` `(/etc/cinder/cinder.conf)`

Tại Compute, có thể thiếu `os_region_name` tại section `[cinder]` `(/etc/nova/nova.conf)`

- Nếu xuất hiện lỗi tại Node Compute

```
2019-04-11 10:58:40.625 14019 ERROR nova.compute.manager [instance: 66eef324-058d-443e-afa6-8893f183a7db] PortBindingFailed: Binding failed for port 68e62053-fed2-4bd8-b3a8-0755012774ad, please check neutron logs for more information.
```

Kiểm tra lại cấu hình neutron và service

- Lỗi khi tạo máy ảo

```
2019-07-12 14:47:49.200 1296 ERROR nova.compute.manager ResourceProviderCreationFailed: Failed to create resource provider compute1
```

Chưa config mục [placement]:

Chỉnh sửa `auth_url` về CTL 10.10.10.117

Sửa `os_region_name` về `RegionTwo`

## 4.6. Redirect dashboard horizon cụm region 2 về horizon cụm region 1

Thao tác trên server horizon region `10.10.10.119`

```
vi /var/www/html/index.html
```

![](../images/img-multipe-region/Screenshot_138.png)

Restart lại httpd

```
systemctl restart httpd.service
```


















