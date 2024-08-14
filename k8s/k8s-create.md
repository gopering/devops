- k8s 集群搭建
        
  - 环境准备
   table:
   - 系统：CentOS 7.6
   - 网络：内网
   - 节点：2 台
   - 存储：40G SSD

  | IP  | 角色   | 内核版本  |
  |------|  ----  |-----| 
  | 192.168.0.31   | master |  CentOS Linux  7.9.2009 (Core)|
  | 192.168.0.32 | work |  CentOS Linux  7.9.2009 (Core)|
- 



  - 安装步骤
     
     1. 关闭防火墙
     ``` shell 
      systemctl stop firewalld
      systemctl disable firewalld
      ```
      
      2. 所有节点都要关闭selinux
       ``` shell 
      setenforce 0
      sed -i '/SELINUX/s/enforcing/disabled/g' /etc/selinux/config
       ```
      
      3. 所有节点都要关闭swap
       ``` shell 
      swapoff -a
      sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
       ```
      
      4. 所有节点都要开启内核模块
      ```  shell
       modprobe ip_vs
       modprobe ip_vs_rr
       modprobe ip_vs_wrr
       modprobe ip_vs_sh
       modprobe nf_conntrack
       modprobe nf_conntrack_ipv4
       modprobe br_netfilter
       modprobe overlay 
     ```

      5. 所有节点都要开启模块自动加载服务
      ```  shell
       cat > /etc/modules-load.d/k8s-modules.conf <<EOF
       ip_vs
       ip_vs_rr
       ip_vs_wrr
       ip_vs_sh
       nf_conntrack
       nf_conntrack_ipv4
       br_netfilter
       overlay
       EOF

      ```
      
      6. 重启服务，并设置为开机自启
      ```  shell
      systemctl enable systemd-modules-load
      systemctl restart systemd-modules-load
    ```
      
      7. 所有节点都要做内核优化
      ```  shell
    cat <<EOF > /etc/sysctl.d/kubernetes.conf
    # 开启数据包转发功能（实现vxlan）
    net.ipv4.ip_forward=1
    # iptables对bridge的数据进行处理
    net.bridge.bridge-nf-call-iptables=1
    net.bridge.bridge-nf-call-ip6tables=1
    net.bridge.bridge-nf-call-arptables=1
    # 关闭tcp_tw_recycle，否则和NAT冲突，会导致服务不通
    net.ipv4.tcp_tw_recycle=0
    # 不允许将TIME-WAIT sockets重新用于新的TCP连接
    net.ipv4.tcp_tw_reuse=0
    # socket监听(listen)的backlog上限
    net.core.somaxconn=32768
    # 最大跟踪连接数，默认 nf_conntrack_buckets * 4
    net.netfilter.nf_conntrack_max=1000000
    # 禁止使用 swap 空间，只有当系统 OOM 时才允许使用它
    vm.swappiness=0
    # 计算当前的内存映射文件数。
    vm.max_map_count=655360
    # 内核可分配的最大文件数
    fs.file-max=6553600
    # 持久连接
    net.ipv4.tcp_keepalive_time=600
    net.ipv4.tcp_keepalive_intvl=30
    net.ipv4.tcp_keepalive_probes=10
    EOF
    ```
      
      8. 配置生效
      ```  shell
      sysctl -p /etc/sysctl.d/kubernetes.conf
      ```
      
      9. 所有节点都要清空 iptables 规则
      ```shell
    iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat
    iptables -P FORWARD ACCEPT
      ```
      
      10. 安装 containerd
    ```shell
    wget -O /etc/yum.repos.d/docker.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum install -y containerd.io
    
    ```

  - [k8s 集群配置](k8s-config.md)
