# Use Node.js 18 slim image (Debian-based)
FROM node:18-slim

# Install essential tools and libraries
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
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/googlechrom-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/googlechrom-keyring.gpg arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Install all Google Fonts (adds ~2GB)
RUN wget https://github.com/google/fonts/archive/main.tar.gz -O gf.tar.gz \
    && tar -xf gf.tar.gz \
    && mkdir -p /usr/share/fonts/truetype/google-fonts \
    && find $PWD/fonts-main/ -name "*.ttf" -exec install -m644 {} /usr/share/fonts/truetype/google-fonts/ \; || true \
    && rm -f gf.tar.gz \
    && fc-cache -fv

# Set environment variables
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY backend/functions/package*.json ./

# Install dependencies
RUN npm ci

# Copy the rest of the application code
COPY backend/functions .

# Build the application
RUN npm run build

# Create local storage directory and set permissions
RUN mkdir -p /app/local-storage && chmod 777 /app/local-storage

# Validate font installation (optional debug step)
RUN fc-list | grep -i "ptsans" && echo "Fonts verified"

# Expose the port the app runs on
EXPOSE 3000

# Start the application
CMD ["node", "build/server.js"]
