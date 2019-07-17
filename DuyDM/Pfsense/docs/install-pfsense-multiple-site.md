# Ghi chép lại các bước cài đặt pfsense multiple site

### Mục lục

[1. Mô hình triển khai](#mohinh)<br>
[2. IP Planning](#planning)<br>
[3. Cài đặt pfsense](#setup)<br>
[4. Config vpn site-to-site](#setup)<br>

## 1. Mô hình triển khai

## 2. IP Planning

## 3. Cài đặt pfsense

Thực hiện cài đặt 2 cụm pssense với các VLAN đã được quy hoạch

### 3.1. Cài đặt pfsense

- Chuẩn bị VM

```
+ vCPU: 4
+ RAM: 6 GB
+ Disk: 30 GB
+ Network: 1 public, n local (n tùy ý)

```

- Cài đặt conmand line

![](../images/img-pfsense-multiple-site/Screenshot_154.png)

![](../images/img-pfsense-multiple-site/Screenshot_155.png)

![](../images/img-pfsense-multiple-site/Screenshot_156.png)

![](../images/img-pfsense-multiple-site/Screenshot_157.png)

![](../images/img-pfsense-multiple-site/Screenshot_158.png)

![](../images/img-pfsense-multiple-site/Screenshot_159.png)

Lựa chọn `No`

![](../images/img-pfsense-multiple-site/Screenshot_160.png)

![](../images/img-pfsense-multiple-site/Screenshot_161.png)

- Config IP WAN,lựa chọn https, cho fpsense

![](../images/img-pfsense-multiple-site/Screenshot_163.png)

- Truy cập config giao diện

```
https://ip
```

Thông tin mặc định `admin\pfsense`

![](../images/img-pfsense-multiple-site/Screenshot_165.png)

![](../images/img-pfsense-multiple-site/Screenshot_166.png)

![](../images/img-pfsense-multiple-site/Screenshot_167.png)

![](../images/img-pfsense-multiple-site/Screenshot_168.png)

Tạm thời để mặc định và click `Next`

![](../images/img-pfsense-multiple-site/Screenshot_169.png)

Đổi pass mặc định sang pass khác có độ khó cao hơn

![](../images/img-pfsense-multiple-site/Screenshot_170.png)

![](../images/img-pfsense-multiple-site/Screenshot_171.png)

![](../images/img-pfsense-multiple-site/Screenshot_172.png)

- Update để lên bản mới để cập nhất các package

![](../images/img-pfsense-multiple-site/Screenshot_173.png)

![](../images/img-pfsense-multiple-site/Screenshot_174.png)

Chờ quá trình update hoàn tất

- Add tất cả các VLAN còn lại trên giao diện pfsense theo mô hình

![](../images/img-pfsense-multiple-site/Screenshot_175.png)

- Thực hiện cài ở 2 site giống nhau

## Bước 2: Cài đặt OpenVPN để client connect tới theo mô hình truyền thống.

## Bước 3: Cấu hình site-to-site


Một số lưu ý:

Rule phải mở ở 2 site giống nhau

+ WAN

![](../images/img-pfsense-multiple-site/Screenshot_178.png)

+ VLAN

![](../images/img-pfsense-multiple-site/Screenshot_179.png)

+ VPN

![](../images/img-pfsense-multiple-site/Screenshot_180.png)

+ IPsec

![](../images/img-pfsense-multiple-site/Screenshot_181.png)

+ OpenVPN

![](../images/img-pfsense-multiple-site/Screenshot_182.png)



























