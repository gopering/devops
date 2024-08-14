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
  

