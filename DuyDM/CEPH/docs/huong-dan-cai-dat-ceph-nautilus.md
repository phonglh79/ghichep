# Ghi chép lại các bước cài đặt CEPH phiên bản nautilus

### Mục lục

[1. Mô hình triển khai](#mohinh)<br>
[2. IP Planning](#planning)<br>
[3. Thiết lập ban đầu](#thietlap)<br>
[4. Cài đặt](#caidat)<br>

<a name="mohinh"></a>
## 1. Mô hình triển khai

Mô hình triển khai gồm 3 node CEPH mỗi node có 3 OSDs.

![](../images/install-ceph-nautilus/topo.png)

**OS** : CentOS7 - 64 bit<br>
**Disk**: 04 HDD, trong đó 01sử dụng để cài OS, 03 sử dụng làm OSD (nơi chứa dữ liệu của client) <br>
**NICs**:
	ens160: dùng để ssh và tải gói cài đặt
	ens192: dùng để các trao đổi thông tin giữa các node Ceph, cũng là đường Client kết nối vào
	ens224: dùng để đồng bộ dữ liệu giữa các OSD
**Phiên bản cài đặt**: Ceph nautilus


<a name="planning"></a>
## 2. IP Planning

![](../images/install-ceph-nautilus/Screenshot_1538.png)

<a name="thietlap"></a>
## 3. Thiết lập ban đầu

**Update**

```
yum install epel-release -y
yum update -y
```

**Cấu hình IP**

Thực hiện trên 3 node với IP đã được quy hoạch cho các node ở mục 2.

```
nmcli c modify ens160 ipv4.addresses 10.10.10.152/24
nmcli c modify ens160 ipv4.gateway 10.10.10.1
nmcli c modify ens160 ipv4.dns 8.8.8.8
nmcli c modify ens160 ipv4.method manual
nmcli con mod ens160 connection.autoconnect yes

nmcli c modify ens192 ipv4.addresses 10.10.13.152/24
nmcli c modify ens192 ipv4.method manual
nmcli con mod ens192 connection.autoconnect yes

nmcli c modify ens224 ipv4.addresses 10.10.14.152/24
nmcli c modify ens224 ipv4.method manual
nmcli con mod ens224 connection.autoconnect yes

sudo systemctl disable firewalld
sudo systemctl stop firewalld
sudo systemctl disable NetworkManager
sudo systemctl stop NetworkManager
sudo systemctl enable network
sudo systemctl start network
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```

![](../images/install-ceph-nautilus/Screenshot_1539.png)

**Kiểm tra đủ disk trên các node CEPH**

![](../images/install-ceph-nautilus/Screenshot_1540.png)

**Bổ sung file hosts**

Thực hiện trên 3 node CEPH.

```
cat << EOF >> /etc/hosts
10.10.13.152 ceph01
10.10.13.153 ceph02
10.10.13.154 ceph03
EOF
```


**Cài đặt NTPD**

```
yum install chrony -y 
```

```
systemctl start chronyd 
systemctl enable chronyd
systemctl restart chronyd 
```
 - Kiểm tra đồng bộ thời gian
 
```
chronyc sources -v
```

![](../images/install-ceph-nautilus/Screenshot_1541.png)

**Kiểm tra kết nối**

Thực hiện trên cả 3 node CEPH.

```
ping -c 10 ceph01
```

![](../images/install-ceph-nautilus/Screenshot_1542.png)

<a name="caidat"></a>
## 4. Cài đặt CEPH

**Cài đặt ceph-deploy**

```
yum install -y wget 
wget https://download.ceph.com/rpm-nautilus/el7/noarch/ceph-deploy-2.0.1-0.noarch.rpm --no-check-certificate
rpm -ivh ceph-deploy-2.0.1-0.noarch.rpm
```

![](../images/install-ceph-nautilus/Screenshot_1543.png)

**Cài đặt `python-setuptools` để `ceph-deploy` có thể hoạt động ổn định.**

```
curl https://bootstrap.pypa.io/ez_setup.py | python
```

![](../images/install-ceph-nautilus/Screenshot_1544.png)

**Kiểm tra cài đặt**

```
ceph-deploy --version
```

Output : `2.0.1` là Ok.

![](../images/install-ceph-nautilus/Screenshot_1545.png)

**Tạo ssh key**

```
ssh-keygen
```

Enter khi có yêu cầu.

![](../images/install-ceph-nautilus/Screenshot_1546.png)

**Copy ssh key sang các node khác**

```
ssh-copy-id root@ceph01
ssh-copy-id root@ceph02
ssh-copy-id root@ceph03
```

![](../images/install-ceph-nautilus/Screenshot_1547.png)

**Tạo các thư mục `ceph-deploy` để thao tác cài đặt vận hành cluster**

```
mkdir /ceph-deploy && cd /ceph-deploy
```

![](../images/install-ceph-nautilus/Screenshot_1548.png)

**Khởi tại file cấu hình cho cụm với node quản lý là `ceph01`**

```
ceph-deploy new ceph01
```

![](../images/install-ceph-nautilus/Screenshot_1549.png)

**Kiểm tra lại thông tin folder `ceph-deploy`**

![](../images/install-ceph-nautilus/Screenshot_1550.png)

`ceph.conf` : file config được tự động khởi tạo

`ceph-deploy-ceph.log` : file log của toàn bộ thao tác đối với việc sử dụng lệnh ceph-deploy.

`ceph.mon.keyring` : Key monitoring được ceph sinh ra tự động để khởi tạo Cluster.

- Bổ sung thêm vào file `ceph.conf`

```
cat << EOF >> /ceph-deploy/ceph.conf
osd pool default size = 2
osd pool default min size = 1
osd crush chooseleaf type = 0
osd pool default pg num = 128
osd pool default pgp num = 128

public network = 10.10.13.0/24
cluster network = 10.10.14.0/24
EOF
```

+ `public network` : Đường trao đổi thông tin giữa các node Ceph và cũng là đường client kết nối vào.

+ `cluster network` : Đường đồng bộ dữ liệu.

![](../images/install-ceph-nautilus/Screenshot_1551.png)

**Cài đặt ceph trên toàn bộ các node ceph**

**Lưu ý**: Nên sử dụng `boybu`, `tmux`, `screen` để cài đặt tránh hiện tượng mất kết nối khi đang cài đặt CEPH.

```
ceph-deploy install --release nautilus ceph01 ceph02 ceph03 
```

![](../images/install-ceph-nautilus/Screenshot_1552.png)

Đợi khoảng 30 phút -> 60 phút để cài xong trên cả 2 node CEPH.

![](../images/install-ceph-nautilus/Screenshot_1553.png)

**Kiểm tra sau khi cài đặt**

```
ceph -v 
```

![](../images/install-ceph-nautilus/Screenshot_1554.png)

Đã cài đặt thành công CEPH trên node.



