# ======== 构建阶段 ========
FROM node:18-slim AS builder

# 基础依赖安装
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget gnupg fonts-noto-cjk fonts-wqy-zenhei \
    && rm -rf /var/lib/apt/lists/*
# Chrome 密钥添加
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
# Chrome 安装
RUN apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# 设置环境变量
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable

# 设置工作目录并安装依赖
WORKDIR /app
COPY backend/functions/package*.json ./
RUN npm ci

# 复制源码并构建
COPY backend/functions .
RUN npm run build

# 分离生产依赖
RUN npm prune --production && cp -R node_modules /tmp/prod_node_modules

# ======== 运行时阶段 ========
FROM node:18-slim

# 安装精简运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnss3 libasound2 libxtst6 libx11-xcb1 libxcomposite1 libxdamage1 \
    libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libatk1.0-0 libatk-bridge2.0-0 \
    fontconfig fonts-noto-cjk fonts-wqy-zenhei libvulkan1 libmagic1 file \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# 创建符号链接解决路径问题
RUN ln -s /usr/lib/x86_64-linux-gnu/libmagic.so.1 /usr/lib/libmagic-1.so \
    && ln -s /usr/lib/x86_64-linux-gnu/libmagic.so.1 /usr/lib/libmagic.so.1
# 验证库文件存在
RUN ls -l /usr/lib/libmagic* && echo "LibMagic verification passed"

# 复制 Chrome 二进制及关键库
COPY --from=builder /usr/bin/google-chrome-stable /usr/bin/
COPY --from=builder /opt/google/chrome /opt/google/chrome
COPY --from=builder /usr/lib/x86_64-linux-gnu/{libvulkan.so.1*,libminizip.so.1*,libsnappy.so.1*} /usr/lib/x86_64-linux-gnu/

# 创建符号链接
RUN ln -s /usr/bin/google-chrome-stable /usr/bin/chrome

# 激活字体并验证
RUN fc-cache -fv && fc-list | grep -i "Noto" || { echo "⚠️ 字体验证失败"; exit 1; }

# 设置工作目录
WORKDIR /app

# 复制生产依赖及构建产物
COPY --from=builder /tmp/prod_node_modules ./node_modules
COPY --from=builder /app/build ./build

# 安全存储目录配置
RUN mkdir -p /app/local-storage \
    && chown node:node /app/local-storage \
    && chmod 750 /app/local-storage

# 切换非特权用户
USER node

# 设置环境变量
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable \
    CHROME_PATH=/usr/bin/google-chrome-stable \
    PUPPETEER_ARGS="--no-sandbox,--disable-setuid-sandbox,--disable-dev-shm-usage"

# 暴露端口
EXPOSE 3000

# 启动命令
CMD ["node", "build/server.js"]
