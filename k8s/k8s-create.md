
# kubeadm + containerd 部署 k8s-v1.23.3



- 前言
- 环境准备
  - 关闭防火墙
  - 关闭selinux
  - 关闭swap
  - 开启内核模块
    - 开启模块自动加载服务
  - 内核优化
  - 清空 iptables 规则
- 安装 containerd
- 配置 kubernetes 源
- 安装 kubeadm 以及 kubelet
  - 配置命令参数自动补全功能
  - 启动 kubelet 服务
- kubeadm 部署 master 节点
  - 安装 flannel 组件
- work 节点加入集群
- master 节点加入集群

## 前言

kubeadm 和二进制部署的区别：

- kubeadm
  - 优点：部署方便，两个参数完成集群部署和节点加入
    1. `kubeadm init` 初始化节点
    2. `kubeadm join` 节点加入集群
  - 缺点：集群证书有效期只有一年
- 二进制部署
  - 优点：自定义集群证书有效期，组件细节可定制
  - 缺点：部署相对复杂

## 环境准备

| IP    | 角色   | 内核版本              |
| ----- | ------ | --------------------- |
| 192.168.91.8 | master | centos7.6/3.10.0-957.el7.x86_64 |
| 192.168.91.9 | work   | centos7.6/3.10.0-957.el7.x86_64 |

### 关闭防火墙

```shell
systemctl disable firewalld
systemctl stop firewalld
```

### 关闭selinux

```shell
setenforce 0
sed -i '/SELINUX/s/enforcing/disabled/g' /etc/selinux/config
```

### 关闭swap

```shell
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### 开启内核模块

```shell
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe nf_conntrack
modprobe nf_conntrack_ipv4
modprobe br_netfilter
modprobe overlay
```

### 开启模块自动加载服务

```shell
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
记得重启服务，并设置为开机自启

    systemctl enable systemd-modules-load
    systemctl restart systemd-modules-load

### 内核优化

```shell
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

让配置生效

    sysctl -p /etc/sysctl.d/kubernetes.conf


### 清空 iptables 规则

```shell
iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat
iptables -P FORWARD ACCEPT
```

## 安装 containerd

```shell
# 配置 docker 源
wget -O /etc/yum.repos.d/docker.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 查找 containerd 安装包
yum search containerd

# 安装 containerd
yum install -y containerd.io
```

## 修改 containerd 配置文件
```yaml
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

## 启动 containerd 服务，并设置为开机启动

    systemctl enable containerd
    systemctl restart containerd

## 配置 kubernetes 源

```shell
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

## 安装 kubeadm 以及 kubelet

```shell
yum install -y kubelet-1.23.3-0 kubeadm-1.23.3-0
```

## 配置命令参数自动补全功能
```shell
yum install -y bash-completion
echo 'source <(kubectl completion bash)' >> $HOME/.bashrc
echo 'source <(kubeadm completion bash)' >> $HOME/.bashrc
source $HOME/.bashrc
```

## 启动 kubelet 服务

    systemctl enable kubelet
    systemctl restart kubelet


# 以上所有节点执行  下面是在master节点执行的操作

## kubeadm 部署 master 节点

    kubeadm config print init-defaults
    vim kubeadm.yaml

kubeadm.yaml 内容

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
  - groups:
      - system:bootstrappers:kubeadm:default-node-token
    token: abcdef.0123456789abcdef
    ttl: 24h0m0s
    usages:
      - signing
      - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.91.8
  bindPort: 6443
nodeRegistration:
  criSocket: /run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  name: 192.168.91.8
  taints: null

---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: 192.168.91.8:6443
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers
kind: ClusterConfiguration
kubernetesVersion: 1.23.3
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: 172.22.0.0/16
scheduler: {}

---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
cgroupsPerQOS: true

---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs

```

## 集群初始化
    kubeadm init --config kubeadm.yaml


以下是 kubeadm init 的过程，
```yaml
[init] Using Kubernetes version: v1.23.3
[preflight] Running pre-flight checks
        [WARNING Service-Kubelet]: kubelet service is not enabled, please run 'systemctl enable kubelet.service'
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [192.168.91.8 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 192.168.91.8]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [192.168.91.8 localhost] and IPs [192.168.91.8 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [192.168.91.8 localhost] and IPs [192.168.91.8 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 12.504586 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.23" in namespace kube-system with the configuration for the kubelets in the cluster
NOTE: The "kubelet-config-1.23" naming of the kubelet ConfigMap is deprecated. Once the UnversionedKubeletConfigMap feature gate graduates to Beta the default name will become just "kubelet-config". Kubeadm upgrade will handle this transition transparently.
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node 192.168.91.8 as control-plane by adding the labels: [node-role.kubernetes.io/master(deprecated) node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node 192.168.91.8 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: abcdef.0123456789abcdef
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join 192.168.91.8:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:5e2387403e698e95b0eab7197837f2425f7b8610e7b400e54d81c27f3c6f1964 \
        --control-plane

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.91.8:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:5e2387403e698e95b0eab7197837f2425f7b8610e7b400e54d81c27f3c6f1964

```
以下操作二选一

kubectl 不加 --kubeconfig 参数，默认找的是 $HOME/.kube/config ，如果不创建目录，并且将证书复制过去，就要生成环境变量，或者每次使用 kubectl 命令的时候，都要加上 --kubeconfig 参数指定证书文件，否则 kubectl 命令就找不到集群了

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

或者
    echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> $HOME/.bashrc
    source ~/.bashrc


查看 k8s 组件运行情况

    kubectl get pods -n kube-system

    NAME                                   READY   STATUS    RESTARTS   AGE
    coredns-65c54cc984-cglz9               0/1     Pending   0          12s
    coredns-65c54cc984-qwd5b               0/1     Pending   0          12s
    etcd-192.168.91.8                      1/1     Running   0          27s
    kube-apiserver-192.168.91.8            1/1     Running   0          21s
    kube-controller-manager-192.168.91.8   1/1     Running   0          21s
    kube-proxy-zwdlm                       1/1     Running   0          12s
    kube-scheduler-192.168.91.8            1/1     Running   0          27s

因为还没有网络组件，coredns 没有运行成功


### 安装 flannel 组件

```yaml
cat <<EOF> flannel.yaml | kubectl apply -f flannel.yaml
---
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: psp.flannel.unprivileged
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: docker/default
    seccomp.security.alpha.kubernetes.io/defaultProfileName: docker/default
    apparmor.security.beta.kubernetes.io/allowedProfileNames: runtime/default
    apparmor.security.beta.kubernetes.io/defaultProfileName: runtime/default
spec:
  privileged: false
  volumes:
    - configMap
    - secret
    - emptyDir
    - hostPath
  allowedHostPaths:
    - pathPrefix: "/etc/cni/net.d"
    - pathPrefix: "/etc/kube-flannel"
    - pathPrefix: "/run/flannel"
  readOnlyRootFilesystem: false
  # Users and groups
  runAsUser:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  # Privilege Escalation
  allowPrivilegeEscalation: false
  defaultAllowPrivilegeEscalation: false
  # Capabilities
  allowedCapabilities: ['NET_ADMIN', 'NET_RAW']
  defaultAddCapabilities: []
  requiredDropCapabilities: []
  # Host namespaces
  hostPID: false
  hostIPC: false
  hostNetwork: true
  hostPorts:
    - min: 0
      max: 65535
  # SELinux
  seLinux:
    # SELinux is unused in CaaSP
    rule: 'RunAsAny'
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
rules:
  - apiGroups: ['policy']
    resources: ['podsecuritypolicies']
    verbs: ['use']
    resourceNames: ['psp.flannel.unprivileged']
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes/status
    verbs:
      - patch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
  - kind: ServiceAccount
    name: flannel
    namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-system
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cfg
  namespace: kube-system
  labels:
    tier: node
    app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "172.22.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds
  namespace: kube-system
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/os
                    operator: In
                    values:
                      - linux
      hostNetwork: true
      priorityClassName: system-node-critical
      tolerations:
        - operator: Exists
          effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
        - name: install-cni
          image: quay.io/coreos/flannel:v0.15.1
          command:
            - cp
          args:
            - -f
            - /etc/kube-flannel/cni-conf.json
            - /etc/cni/net.d/10-flannel.conflist
          volumeMounts:
            - name: cni
              mountPath: /etc/cni/net.d
            - name: flannel-cfg
              mountPath: /etc/kube-flannel/
      containers:
        - name: kube-flannel
          image: quay.io/coreos/flannel:v0.15.1
          command:
            - /opt/bin/flanneld
          args:
            - --ip-masq
            - --kube-subnet-mgr
          resources:
            requests:
              cpu: "100m"
              memory: "50Mi"
            limits:
              cpu: "100m"
              memory: "50Mi"
          securityContext:
            privileged: false
            capabilities:
              add: ["NET_ADMIN", "NET_RAW"]
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          volumeMounts:
            - name: run
              mountPath: /run/flannel
            - name: flannel-cfg
              mountPath: /etc/kube-flannel/
      volumes:
        - name: run
          hostPath:
            path: /run/flannel
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: flannel-cfg
          configMap:
            name: kube-flannel-cfg
  EOF

```

稍等 2-3 分钟，等待 flannel pod 成为 running 状态 （具体时间视镜像下载速度）

    NAME                                   READY   STATUS    RESTARTS   AGE
    coredns-65c54cc984-cglz9               1/1     Running   0          2m7s
    coredns-65c54cc984-qwd5b               1/1     Running   0          2m7s
    etcd-192.168.91.8                      1/1     Running   0          2m22s
    kube-apiserver-192.168.91.8            1/1     Running   0          2m16s
    kube-controller-manager-192.168.91.8   1/1     Running   0          2m16s
    kube-flannel-ds-26drg                  1/1     Running   0          100s
    kube-proxy-zwdlm                       1/1     Running   0          2m7s
    kube-scheduler-192.168.91.8            1/1     Running   0          2m22s


## work 节点加入集群
在 master 节点初始化完成的时候，已经给出了加入集群的参数

只需要复制一下，到 work 节点执行即可

--node-name 参数定义节点名称，如果是主机名需要保证可以解析（kubectl get nodes 命令查看到的节点名称）


```shell
    kubeadm join 192.168.91.8:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:5e2387403e698e95b0eab7197837f2425f7b8610e7b400e54d81c27f3c6f1964 \
    --node-name 192.168.91.9
```


如果忘记记录了，或者以后需要增加节点怎么办？
执行下面的命令就可以了
 
    kubeadm token create --print-join-command --ttl=0

输出也很少，这个时候只需要去 master 节点执行 kubectl get nodes 命令就可以查看节点的状态了
     
```yaml
[preflight] Running pre-flight checks
        [WARNING Service-Kubelet]: kubelet service is not enabled, please run 'systemctl enable kubelet.service'
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```


节点变成 Ready 的时间取决于 work 节点的 flannel 镜像拉取时间
可以通过 kubectl get node -n kube-system 查看 flannel 是否为 Running 状态
   
    NAME           STATUS   ROLES                  AGE     VERSION
    192.168.91.8   Ready    control-plane,master   9m34s   v1.23.3
    192.168.91.9   Ready    <none>                 6m11s   v1.23.3


  
## 验证集群状态

```shell
kubectl get nodes
```

## master 节点加入集群
需要先从其中一个 master 节点获取 CA 键哈希值
这个值在 kubeadm init 完成时也是已经输出到终端了
kubeadm init 时如果有修改过 certificatesDir 参数，/etc/kubernetes/pki/ca.crt 这里的路径需要注意确认和修改
获取到的 hash 值，使用格式： sha256:<hash 值>

```shell
  openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
```
也可以直接创建新的 token ，并且会给出 hash 值，并给出如下的命令，只需要加上--certificate-key 和 --control-plane 参数即可

     kubeadm join 192.168.91.8:6443 --token 352obx.dw7rqphzxo6cvz9r --discovery-token-ca-cert-hash sha256:5e2387403e698e95b0eab7197837f2425f7b8610e7b400e54d81c27f3c6f1964

```shell
kubeadm token create --print-join-command --ttl=0
```


解密由 kubeadm init 上传的证书 secret 对应的 kubeadm join 参数为 --certificate-key

    kubeadm init phase upload-certs --upload-certs



在需要扩容的 master 节点执行 kubeadm join 命令加入集群

--node-name 参数定义节点名称，如果是主机名需要保证可以解析（kubectl get nodes 命令查看到的节点名称）


```yaml
kubeadm join 192.168.91.8:6443 --token abcdef.0123456789abcdef \
--discovery-token-ca-cert-hash sha256:5e2387403e698e95b0eab7197837f2425f7b8610e7b400e54d81c27f3c6f1964 \
--certificate-key a7a12fb565bf94c768f0097898926e4d0805eb7ecc1477b48fdaaf4d27eb26b0 \
--control-plane \
--node-name 192.168.91.10

```
查看节点

    kubectl get nodes

    NAME            STATUS   ROLES                  AGE    VERSION
    192.168.91.10   Ready    control-plane,master   96m    v1.23.3
    192.168.91.8    Ready    control-plane,master   161m   v1.23.3
    192.168.91.9    Ready    <none>                 158m   v1.23.3

查看 master 组件

    kubectl get pod -n kube-system | egrep -v 'flannel|dns'


    NAME                                    READY   STATUS    RESTARTS      AGE
    etcd-192.168.91.10                      1/1     Running   0             97m
    etcd-192.168.91.8                       1/1     Running   0             162m
    kube-apiserver-192.168.91.10            1/1     Running   0             97m
    kube-apiserver-192.168.91.8             1/1     Running   0             162m
    kube-controller-manager-192.168.91.10   1/1     Running   0             97m
    kube-controller-manager-192.168.91.8    1/1     Running   0             162m
    kube-proxy-6cczc                        1/1     Running   0             158m
    kube-proxy-bfmzz                        1/1     Running   0             97m
    kube-proxy-zwdlm                        1/1     Running   0             162m
    kube-scheduler-192.168.91.10            1/1     Running   0             97m
    kube-scheduler-192.168.91.8             1/1     Running   0             162m
