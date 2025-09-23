#!/bin/sh
set -x
systemctl stop k3s
systemctl disable k3s
systemctl daemon-reload
rm -f /etc/systemd/system/k3s.service
rm -f /usr/local/bin/k3s
if [ -L /usr/local/bin/kubectl ]; then
    rm -f /usr/local/bin/kubectl
fi
if [ -L /usr/local/bin/crictl ]; then
    rm -f /usr/local/bin/crictl
fi
if [ -e /sys/fs/cgroup/systemd/system.slice/k3s.service/cgroup.procs ]; then
    kill -9 `cat /sys/fs/cgroup/systemd/system.slice/k3s.service/cgroup.procs`
fi
umount `cat /proc/self/mounts | awk '{print $2}' | grep '^/run/k3s'`
umount `cat /proc/self/mounts | awk '{print $2}' | grep '^/var/lib/rancher/k3s'`

rm -rf /var/lib/rancher/k3s
rm -rf /etc/rancher/k3s

rm -f /usr/local/bin/k3s-uninstall.sh