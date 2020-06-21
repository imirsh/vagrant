#!/bin/bash
#
# 关闭防火墙和selinux
for i in stop disable ;do sudo systemctl $i firewalld; done
setenforce 0 && sudo sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
# 时间同步
systemctl enable chronyd.service &&  systemctl start chronyd.service && systemctl status chronyd.service && chronyc sources


yum install -y conntrack ipvsadm ipset jq iptables curl sysstat lrzsz

modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl  --system

yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y docker-ce-18.06.0.ce-3.el7

mkdir /etc/docker && cat > /etc/docker/daemon.json << EOF
{
        "registry-mirrors": ["https://o4uba187.mirror.aliyuncs.com"],
        "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

for i in enable restart; do systemctl restart docker ;done

