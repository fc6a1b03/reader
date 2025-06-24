# 使用 Node.js 18 精简镜像（基于 Debian）
FROM node:18-slim

# 安装核心工具、库及字体包
RUN apt-get update && apt-get install -y \
    chromium \
    libmagic-dev \
    build-essential \
    python3 \
    wget \
    gnupg \
    fontconfig \
    fonts-dejavu \
    fonts-liberation \
    fonts-freefont-ttf \
    fonts-noto \
    fonts-noto-cjk \
    fonts-wqy-zenhei \
    fonts-ipafont \
    fonts-unfonts-core \
    libfreetype6 \
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/googlechrom-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/googlechrom-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# 安装 Google Fonts（包含 PTSans）
RUN mkdir -p /usr/share/fonts/truetype/google-fonts \
    && wget -q https://github.com/google/fonts/archive/main.tar.gz -O gf.tar.gz \
    && tar -xf gf.tar.gz --strip-components=1 -C /usr/share/fonts/truetype/google-fonts \
    && rm gf.tar.gz \
    && fc-cache -fv

# 设置环境变量
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable

# 工作目录设置
WORKDIR /app

# 复制依赖文件并安装
COPY backend/functions/package*.json ./
RUN npm ci

# 复制应用代码
COPY backend/functions .

# 构建应用
RUN npm run build

# 创建存储目录
RUN mkdir -p /app/local-storage && chmod 777 /app/local-storage

# 字体验证（修正版）
RUN fc-list | grep -i "PT[[:space:]]*Sans" \  # 兼容空格变体 [[39][58]]
    && echo "Fonts verified" \
    || { echo "[WARN] PTSans not found. Installed fonts:"; fc-list; }

# 暴露端口
EXPOSE 3000

# 启动命令
CMD ["node", "build/server.js"]
