# 基于 Ubuntu 22.04，稳定且软件包较新
FROM ubuntu:22.04

# 设置环境变量，避免安装过程中的交互提示
ENV DEBIAN_FRONTEND=noninteractive

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

# 3. 暴露端口 (假设你的 C++ 服务运行在 8080)
EXPOSE 8080

# 3.5. 复制 entrypoint 脚本
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 4. 启动时自动 clone 代码，完成后保持容器运行
ENTRYPOINT ["/entrypoint.sh"]