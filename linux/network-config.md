
- 个人搭建的虚拟机centos7，网络配置如下：
   ```shell
    // 找到网卡的配置文件
    cd /etc/sysconfig/network-scripts/
    ls
    // 找到一个ifcfg-enp0s3 的配置文件
    // 编辑它
    vi ifcfg-enp0s3
    
    
    
    // 修改下面的两项
    // 将BOOTPROTO=dhcp 修改为 BOOTPROTO=static  意思是IP设置为固定的
    // 将ONBOOT=no 修改为ONBOOT=yes
    
    // 添加以下配置 
    // 以下以192.168.1开头的配置请根据个人实际的网段配置
    
    # ip
    IPADDR=192.168.1.123
    NETWORK=192.168.1.1
    NETSTAT=255.255.255.0
    GATEWAY=192.168.1.1
    DNS1=192.168.1.1
    DNS2=8.8.8.8
    
    // :wq  保存
    
    // 重启网络
    service network restart
    // 查看ip
    ip addr
    // ping网关
    ping 192.168.1.1
    // ping外网
    ping www.qq.com
    // 如果都能成功 ping 通,说明网络已经配置成功
    
    // *** 桥接模式****
    // 如果检查配置发现没问题,但是网络就是不能正常访问
    // 请检查一下虚拟机的网络是不是配置的 桥接模式 具体可参考上面的设置网络
    // 如果未生效,那就执行命令重启,reboot
   ```
  
 - 执行yum update 更新软件包 出现 `Cannot find a valid baseurl for repo: base/7/x86_64` 错误，解决方法如下：
    ```shell
    // 编辑/etc/yum.repos.d/CentOS-Base.repo文件
    vi /etc/yum.repos.d/CentOS-Base.repo
    // 替换为阿里云的镜像仓库
   
   [base]
    name=CentOS-$releasever - Base
    baseurl=http://mirror.centos.org/centos/$releasever/os/$basearch/
    gpgcheck=1
    gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7
    
    [updates]
    name=CentOS-$releasever - Updates
    baseurl=http://mirror.centos.org/centos/$releasever/updates/$basearch/
    gpgcheck=1
    gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7
    
    [extras]
    name=CentOS-$releasever - Extras
    baseurl=http://mirror.centos.org/centos/$releasever/extras/$basearch/
    gpgcheck=1
    gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7

   
    // 保存退出
    // 然后执行以下命令
    yum clean all
    yum makecache
    // 再次执行 yum update 即可
   
   
    
