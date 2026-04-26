# 基于 Ubuntu 22.04，稳定且软件包较新
FROM ubuntu:22.04

# 设置环境变量，避免安装过程中的交互提示
ENV DEBIAN_FRONTEND=noninteractive

# Git 仓库地址，构建时传入
ARG GIT_REPO_URL

# 1. 安装基础工具：编译器、构建工具、Git、SSH (方便 VSCode 远程连接)
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    cmake \
    make \
    git \
    vim \
    openssh-server \
    openssh-client \
    mysql-client \
    libmysqlclient-dev \
    libboost-all-dev \
    libasio-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. 设置工作目录
WORKDIR /app

# 3. 构建阶段：clone 代码并编译
RUN if [ -n "$GIT_REPO_URL" ]; then \
      git clone --recursive "$GIT_REPO_URL" /app/code && \
      cd /app/code && make; \
    else \
      echo "[WARN] GIT_REPO_URL not set, skipping build"; \
    fi

# 4. 暴露端口 (假设你的 C++ 服务运行在 8080)
EXPOSE 8080

# 5. 复制 entrypoint 脚本
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 6. 启动时直接运行 server
ENTRYPOINT ["/entrypoint.sh"]