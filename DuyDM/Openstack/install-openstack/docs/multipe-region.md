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

