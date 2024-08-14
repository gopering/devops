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
      11. 配置 containerd
     ```shell
     cat <<EOF > /etc/containerd/config.toml
     disabled_plugins = []
     imports = []
     oom_score = 0
     plugin_dir = ""
     required_plugins = []
     root = "/approot1/data/containerd"
     state = "/run/containerd"
     version = 2
    
    [cgroup]
    path = ""
    
    [debug]
    address = ""
    format = ""
    gid = 0
    level = ""
    uid = 0
    
    [grpc]
    address = "/run/containerd/containerd.sock"
    gid = 0
    max_recv_message_size = 16777216
    max_send_message_size = 16777216
    tcp_address = ""
    tcp_tls_cert = ""
    tcp_tls_key = ""
    uid = 0
    
    [metrics]
    address = ""
    grpc_histogram = false
    
    [plugins]
    
    [plugins."io.containerd.gc.v1.scheduler"]
    deletion_threshold = 0
    mutation_threshold = 100
    pause_threshold = 0.02
    schedule_delay = "0s"
    startup_delay = "100ms"
    
    [plugins."io.containerd.grpc.v1.cri"]
    disable_apparmor = false
    disable_cgroup = false
    disable_hugetlb_controller = true
    disable_proc_mount = false
    disable_tcp_service = true
    enable_selinux = false
    enable_tls_streaming = false
    ignore_image_defined_volumes = false
    max_concurrent_downloads = 3
    max_container_log_line_size = 16384
    netns_mounts_under_state_dir = false
    restrict_oom_score_adj = false
    sandbox_image = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.6"
    selinux_category_range = 1024
    stats_collect_period = 10
    stream_idle_timeout = "4h0m0s"
    stream_server_address = "127.0.0.1"
    stream_server_port = "0"
    systemd_cgroup = false
    tolerate_missing_hugetlb_controller = true
    unset_seccomp_profile = ""
    
        [plugins."io.containerd.grpc.v1.cri".cni]
          bin_dir = "/opt/cni/bin"
          conf_dir = "/etc/cni/net.d"
          conf_template = "/etc/cni/net.d/cni-default.conf"
          max_conf_num = 1
    
        [plugins."io.containerd.grpc.v1.cri".containerd]
          default_runtime_name = "runc"
          disable_snapshot_annotations = true
          discard_unpacked_layers = false
          no_pivot = false
          snapshotter = "overlayfs"
    
          [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
            base_runtime_spec = ""
            container_annotations = []
            pod_annotations = []
            privileged_without_host_devices = false
            runtime_engine = ""
            runtime_root = ""
            runtime_type = ""
    
            [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime.options]
    
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
    
            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
              base_runtime_spec = ""
              container_annotations = []
              pod_annotations = []
              privileged_without_host_devices = false
              runtime_engine = ""
              runtime_root = ""
              runtime_type = "io.containerd.runc.v2"
    
              [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
                BinaryName = ""
                CriuImagePath = ""
                CriuPath = ""
                CriuWorkPath = ""
                IoGid = 0
                IoUid = 0
                NoNewKeyring = false
                NoPivotRoot = false
                Root = ""
                ShimCgroup = ""
                SystemdCgroup = true
    
          [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime]
            base_runtime_spec = ""
            container_annotations = []
            pod_annotations = []
            privileged_without_host_devices = false
            runtime_engine = ""
            runtime_root = ""
            runtime_type = ""
    
            [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime.options]
    
        [plugins."io.containerd.grpc.v1.cri".image_decryption]
          key_model = "node"
    
        [plugins."io.containerd.grpc.v1.cri".registry]
          config_path = ""
    
          [plugins."io.containerd.grpc.v1.cri".registry.auths]
    
          [plugins."io.containerd.grpc.v1.cri".registry.configs]
    
          [plugins."io.containerd.grpc.v1.cri".registry.headers]
    
          [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
            [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
              endpoint = ["https://docker.mirrors.ustc.edu.cn", "http://hub-mirror.c.163.com"]
            [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
              endpoint = ["https://gcr.mirrors.ustc.edu.cn"]
            [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
              endpoint = ["https://gcr.mirrors.ustc.edu.cn/google-containers/"]
            [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
              endpoint = ["https://quay.mirrors.ustc.edu.cn"]
    
        [plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming]
          tls_cert_file = ""
          tls_key_file = ""
    
    [plugins."io.containerd.internal.v1.opt"]
    path = "/opt/containerd"
    
    [plugins."io.containerd.internal.v1.restart"]
    interval = "10s"
    
    [plugins."io.containerd.metadata.v1.bolt"]
    content_sharing_policy = "shared"
    
    [plugins."io.containerd.monitor.v1.cgroups"]
    no_prometheus = false
    
    [plugins."io.containerd.runtime.v1.linux"]
    no_shim = false
    runtime = "runc"
    runtime_root = ""
    shim = "containerd-shim"
    shim_debug = false
    
    [plugins."io.containerd.runtime.v2.task"]
    platforms = ["linux/amd64"]
    
    [plugins."io.containerd.service.v1.diff-service"]
    default = ["walking"]
    
    [plugins."io.containerd.snapshotter.v1.aufs"]
    root_path = ""
    
    [plugins."io.containerd.snapshotter.v1.btrfs"]
    root_path = ""
    
    [plugins."io.containerd.snapshotter.v1.devmapper"]
    async_remove = false
    base_image_size = ""
    pool_name = ""
    root_path = ""
    
    [plugins."io.containerd.snapshotter.v1.native"]
    root_path = ""
    
    [plugins."io.containerd.snapshotter.v1.overlayfs"]
    root_path = ""
    
    [plugins."io.containerd.snapshotter.v1.zfs"]
    root_path = ""
    
    [proxy_plugins]
    
    [stream_processors]
    
    [stream_processors."io.containerd.ocicrypt.decoder.v1.tar"]
    accepts = ["application/vnd.oci.image.layer.v1.tar+encrypted"]
    args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
    env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
    path = "ctd-decoder"
    returns = "application/vnd.oci.image.layer.v1.tar"
    
    [stream_processors."io.containerd.ocicrypt.decoder.v1.tar.gzip"]
    accepts = ["application/vnd.oci.image.layer.v1.tar+gzip+encrypted"]
    args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
    env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
    path = "ctd-decoder"
    returns = "application/vnd.oci.image.layer.v1.tar+gzip"
    
    [timeouts]
    "io.containerd.timeout.shim.cleanup" = "5s"
    "io.containerd.timeout.shim.load" = "5s"
    "io.containerd.timeout.shim.shutdown" = "3s"
    "io.containerd.timeout.task.state" = "2s"
    
    [ttrpc]
    address = ""
    gid = 0
    uid = 0
    EOF
    ```
  

  - [k8s 集群配置](k8s-config.md)
