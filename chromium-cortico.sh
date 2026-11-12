#!/bin/sh
# Cortico 用的 Chromium 启动器。
# 两个必须：DISPLAY 指向容器内的 Xvfb（cortico 是 headless，没有真屏），
# 以及 --no-sandbox（容器里以 root 跑，Chromium 会拒绝启动）。
export DISPLAY=:99
# 注意：不能加 --disable-software-rasterizer。目标机器没有 GPU，
# Chromium 只能靠 SwiftShader 软件渲染，禁掉它会直接黑屏。
exec /usr/bin/chromium \
  --no-sandbox \
  --disable-gpu \
  --disable-dev-shm-usage \
  --enable-unsafe-swiftshader \
  "$@"
