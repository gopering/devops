#!/bin/bash

# 设置 Kubernetes 配置环境变量

# 定义 KUBECONFIG 环境变量
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bash_profile

# 重新加载 .bash_profile 以应用更改
source ~/.bash_profile

echo "KUBECONFIG 环境变量已设置。"
