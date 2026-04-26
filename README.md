# Docker 部署指南

## 目录结构

```
├── .env                # 环境变量配置（复制 .env.example 修改）
├── .env.example        # 环境变量模板
├── docker-compose.yml  # 容器编排配置
├── docker/
│   ├── Dockerfile      # 应用容器构建
│   └── entrypoint.sh   # 容器启动入口脚本
├── nginx.conf          # Nginx 配置
└── code/               # 代码目录（git clone 自动生成）
```

## 环境要求

- Docker Engine + Docker Compose v2
- 已配置的 GitHub SSH 密钥（仓库为私有仓库时）

## 快速开始

### 1. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env`，填入你的配置：

```env
# Git 仓库配置
GIT_REPO_URL=git@github.com:apEeach/DS_Course.git
GIT_SSH_KEY_PATH=/home/user/.ssh/id_ed25519

# 控制开关
ENABLE_MYSQL=true
ENABLE_INIT_DB=true

# 数据库配置
DB_HOST=db
DB_USER=root
DB_PASS=your_password
DB_NAME=mydb
```

| 变量 | 说明 |
|---|---|
| `GIT_REPO_URL` | 代码仓库地址（SSH 格式） |
| `GIT_SSH_KEY_PATH` | SSH 私钥在**宿主机**上的绝对路径 |
| `ENABLE_MYSQL` | `true` 启动内置 MySQL，`false` 使用外部数据库 |
| `ENABLE_INIT_DB` | `true` 执行 `init_db.sh` 初始化数据库，`false` 跳过 |
| `DB_HOST` | 数据库地址，使用内置 MySQL 时填 `db` |
| `DB_USER` / `DB_PASS` / `DB_NAME` | 数据库账号、密码、库名 |

### 2. 构建并启动

#### 场景 A：完整启动（内置 MySQL + 数据库初始化 + App + Nginx）

```bash
docker compose --profile mysql up -d --build
```

#### 场景 B：不使用内置 MySQL（外部数据库 + App + Nginx）

```bash
docker compose up -d --build
```

> 不加 `--profile mysql` 就不会启动 MySQL 容器。

#### 场景 C：不执行数据库初始化脚本

在 `.env` 中设置 `ENABLE_INIT_DB=false`，然后正常启动即可。

### 3. 启动流程

```
db (可选) → app (clone代码 → make → init_db.sh → server) → nginx (健康检查通过后启动)
```

app 容器的健康检查：当 `/app/code/.git` 存在时视为 healthy，nginx 才会启动。

### 4. 验证服务

```bash
# 查看所有运行中的容器
docker compose ps

# 查看 app 日志
docker compose logs -f app

# 查看 Nginx 日志
docker compose logs -f nginx

# 进入 app 容器调试
docker exec -it my_cpp_dev bash
```

## 常用操作

| 操作 | 命令 |
|---|---|
| 查看日志 | `docker compose logs -f app` |
| 进入容器 | `docker exec -it my_cpp_dev bash` |
| 重启所有 | `docker compose restart` |
| 重建镜像 | `docker compose up -d --build` |
| 停止并删除容器 | `docker compose down` |
| 停止并删除全部（含 mysql） | `docker compose --profile mysql down` |
| 清理 mysql 数据 | `docker compose --profile mysql down && rm -rf mysql_data/` |

## 常见问题

### SSH key 挂载失败

确保 `.env` 中 `GIT_SSH_KEY_PATH` 是宿主机的**绝对路径**，且文件存在。

### Nginx 返回 403/404

`./code/webSource` 目录下没有静态文件，确认仓库代码已正确 clone。

### 子模块 clone 失败

```bash
docker exec -it my_cpp_dev bash
cd /app/code
git submodule deinit -f deps/Crow
rm -rf deps/Crow
git submodule update --init deps/Crow
```

### 不想用内置 MySQL

1. `.env` 中设置 `DB_HOST=<你的数据库地址>`
2. 启动时不加 `--profile mysql`：
   ```bash
   docker compose up -d --build
   ```
