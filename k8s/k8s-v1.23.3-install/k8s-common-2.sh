#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# 配置命令补全
echo "正在配置命令参数自动补全功能..."
yum install -y bash-completion

# 追加命令补全配置到 .bashrc
BASHRC="$HOME/.bashrc"

# 确保 bash-completion 被加载
if ! grep -q "source /usr/share/bash-completion/bash_completion" "$BASHRC"; then
    echo 'source /usr/share/bash-completion/bash_completion' >> "$BASHRC"
fi

# 追加 kubectl 和 kubeadm 补全
if ! grep -q "kubectl completion bash" "$BASHRC"; then
    echo 'source <(kubectl completion bash)' >> "$BASHRC"
fi

if ! grep -q "kubeadm completion bash" "$BASHRC"; then
    echo 'source <(kubeadm completion bash)' >> "$BASHRC"
fi

# 使配置生效
source "$BASHRC"

# 启动 kubelet 服务
echo "正在启动 kubelet 服务..."
systemctl enable kubelet && systemctl restart kubelet

echo "脚本执行完成！"
echo "Kubernetes common  公共步骤第二步--集群自动化安装脚本执行完毕。"


