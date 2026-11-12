FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# 换阿里云源（arm64），避开 deb.debian.org 慢/超时
RUN if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
      sed -i 's|deb.debian.org|mirrors.aliyun.com|g; s|security.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources; \
    elif [ -f /etc/apt/sources.list ]; then \
      sed -i 's|deb.debian.org|mirrors.aliyun.com|g; s|security.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list; \
    fi

# 1) node-canvas 编译与运行时依赖 + git（扩展安装用）
# 2) chromium：bilibili-video world 要真浏览器（headful，无 --headless）
# 3) fonts-wqy-zenhei：不装的话 B 站页面中文全是方块，模型等于看空白
# 4) xvfb：目标机器没有显示器，Chromium 必须有一块虚拟屏
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates python3 make g++ pkg-config \
      libcairo2-dev libpango1.0-dev libjpeg62-turbo-dev libgif-dev librsvg2-dev \
      chromium fonts-wqy-zenhei xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@11.28.6 --activate

WORKDIR /app

# 先只拷清单，让依赖层可缓存；store 用 BuildKit 缓存，重建时不用重新下载
COPY repo/package.json repo/pnpm-lock.yaml repo/pnpm-workspace.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm config set registry https://registry.npmmirror.com \
    && NODE_OPTIONS=--max-old-space-size=4096 pnpm install --frozen-lockfile

# 再拷源码并构建 WebUI 产物
COPY repo/ ./
RUN NODE_OPTIONS=--max-old-space-size=6144 pnpm build:web

# 容器里没有浏览器时，启动时打开 WebUI 的调用若 spawn 失败会变成 uncaughtException
# 直接把进程带走（Error: spawn xdg-open ENOENT）。放一个空操作的替身兜住。
RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/xdg-open && chmod +x /usr/local/bin/xdg-open

# Chromium 启动器：补上 world 不给的两样东西——DISPLAY（headless 机器没有）和
# --no-sandbox（容器里是 root，Chromium 会拒绝启动）。world 的 spawn 参数原样透传。
COPY chromium-cortico.sh /usr/local/bin/chromium-cortico
RUN chmod +x /usr/local/bin/chromium-cortico

# 启动脚本：先清 X socket 残留、拉起 Xvfb，再交给 Cortico
COPY cortico-entrypoint.sh /usr/local/bin/cortico-entrypoint.sh
RUN chmod +x /usr/local/bin/cortico-entrypoint.sh

ENV CORTICO_HOME=/data
ENV TZ=Asia/Shanghai

EXPOSE 7788

CMD ["/usr/local/bin/cortico-entrypoint.sh", "soulmate", "--host=0.0.0.0", "--port=7788"]
