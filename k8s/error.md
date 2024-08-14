- 错误集锦并附带解决方案
  ``` 
  错误 1
  
  There are no enabled repos.
  Run "yum repolist all" to see the repos you have.
  To enable Red Hat Subscription Management repositories:
  subscription-manager repos --enable <repo>
  To enable custom repositories:
  yum-config-manager --enable <repo>

  解决方法，卸载并且重装yum 
  1 首先输入这行代码     移除yum
  
  mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
  2在输入这行代码  安装yum
  
  wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo



```
   错误 2
   root@k8s-master:~# crictl  images ls 
WARN[0000] image connect using default endpoints: [unix:///var/run/dockershim.sock unix:///run/containerd/containerd.sock unix:///run/crio/crio.sock unix:///var/run/cri-dockerd.sock]. As the default settings are now deprecated, you should set the endpoint instead. 
E0623 08:08:57.723814  239026 remote_image.go:119] "ListImages with filter from image service failed" err="rpc error: code = Unavailable desc = connection error: desc = \"transport: Error while dialing dial unix /var/run/dockershim.sock: connect: no such file or directory\"" filter="&ImageFilter{Image:&ImageSpec{Image:ls,Annotations:map[string]string{},},}"
FATA[0000] listing images: rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing dial unix /var/run/dockershim.sock: connect: no such file or directory" 
    

 解决方法：
 
cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 0
debug: false
pull-image-on-create: false
EOF


root@k8s-master:~# crictl  images ls 
IMAGE                                                                TAG                 IMAGE ID            SIZE
docker.io/flannel/flannel-cni-plugin                                 v1.1.2              7a2dcab94698c       3.84MB
docker.io/flannel/flannel                                            v0.22.0             38c11b8f4aa19       26.9MB
docker.io/library/nginx                                              latest              eb4a571591807       70.6MB
registry.aliyuncs.com/google_containers/coredns                      v1.10.1             ead0a4a53df89       16.2MB
registry.aliyuncs.com/google_containers/etcd                         3.5.7-0             86b6af7dd652c       102MB
registry.aliyuncs.com/google_containers/kube-apiserver               v1.27.1             6f6e73fa8162b       33.4MB
registry.aliyuncs.com/google_containers/kube-controller-manager      v1.27.1             c6b5118178229       31MB
