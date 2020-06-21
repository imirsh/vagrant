#!/bin/bash
#
# 主机名解析
cat >> /etc/hosts << EOF
192.168.124.201 master01.linux.io master01
192.168.124.202 master02.linux.io master02
192.168.124.203 master03.linux.io master03
192.168.124.101 node01.linux.io   node01
192.168.124.201 node01.linux.io   node01
EOF

# 关闭防火墙和 selinux
for i in stop disable ;do systemctl $i firewalld; done
setenforce 0 && sudo sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config

# 时间同步
systemctl enable chronyd.service &&  systemctl start chronyd.service && systemctl status chronyd.service && chronyc sources

# 关闭swap分区
swapoff -a && sudo sed -i 's/.*swap.*/#&/' /etc/fstab

# 安装依赖
yum install -y conntrack ipvsadm ipset jq iptables curl sysstat lrzsz

# 调整内核参数
modprobe overlay
modprobe br_netfilter
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl  --system

# 安装 docker
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y docker-ce-18.06.0.ce-3.el7

# 配置docker 加速
mkdir /etc/docker
cat  > /etc/docker/daemon.json << EOF
{
        "registry-mirrors": ["https://o4uba187.mirror.aliyuncs.com"],
        "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

# 启动docker
for i in enable restart; do systemctl restart docker ;done

# 升级内核
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
yum --enablerepo=elrepo-kernel info  kernel-lt
yum --enablerepo=elrepo-kernel install  kernel-lt
# awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg
grub2-set-default "CentOS Linux (4.4.226-1.el7.elrepo.x86_64) 7 (Core)"



# 加载 ipvs 模块
cat >  /etc/sysconfig/modules/ipvs.modules << EOF
#!/bin/bash
ipvs_mods_dir="/usr/lib/modules/$(uname -r)/kernel/net/netfilter/ipvs"
for mod in $(ls $ipvs_mods_dir | grep -o "^[^.]*"); do
    /sbin/modinfo -F filename $mod  &> /dev/null
    if [ $? -eq 0 ]; then
        /sbin/modprobe $mod
    fi
done
EOF

chmod  +x /etc/sysconfig/modules/ipvs.modules
bash /etc/sysconfig/modules/ipvs.modules

# 配置 Kubeadm 仓库
cat  > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# yum install -y  kubeadm-1.16.10 kubelet-1.16.10 kubectl-1.16.10
# systemctl enable kubelet

# kubeadm init  --kubernetes-version=v1.16.10 --apiserver-advertise-address=192.168.124.201 \
#   --pod-network-cidr=10.244.0.0/16  \
#   --service-cidr=10.96.0.0/12
#   --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers \
#   --ignore-preflight-errors=Swap | tee kubeadm-init.log
