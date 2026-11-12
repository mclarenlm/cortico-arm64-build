#!/bin/sh
set -u

export DISPLAY=:99

# 容器重启会留下旧的 socket / lock，Xvfb 见到就报 "server already running" 并拒绝启动
rm -f /tmp/.X99-lock
rm -rf /tmp/.X11-unix
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

Xvfb :99 -screen 0 1280x800x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
sleep 2

# 单实例锁记的是容器内 pid，重建容器后指向不存在的进程 → 死循环重启
rm -f /data/soulmate/data/instance.lock

exec node bin/cortico.mjs "$@"
