# 课程培训平台

面向职业技能培训的 B2C 课程平台，支持微信小程序端用户购课、签到，以及后台管理系统进行课程运营和学员管理。

## 技术栈

- **后端**：C++（GCC）、MySQL 8.0
- **数据库迁移**：Flyway
- **容器化**：Docker + Docker Compose
- **CI/CD**：GitHub Actions + 阿里云 ACR
- **反向代理**：Nginx

## 目录结构

```
├── .env                # 环境变量配置（本地开发 & CI/CD 构建用）
├── docker/
│   ├── Dockerfile      # 应用容器构建（构建时 clone 代码 + 编译）
│   └── entrypoint.sh   # 容器启动入口脚本（初始化 + 启动服务）
├── docker-compose.yml  # 容器编排配置
├── nginx.conf          # Nginx 配置（server_name 通过环境变量注入）
├── migrations/
│   └── V1__initial_schema.sql   # Flyway 数据库迁移脚本
├── docs/
│   ├── PRD.md          # 产品需求文档
│   └── db.md           # 数据库设计文档
└── .github/workflows/
    └── deploy.yml      # CI/CD 自动化构建 & 部署
```

## 部署架构

```
本地代码 ──push──> GitHub ──trigger──> CI/CD
                                        │
                              ┌─────────┴──────────┐
                              │  build-and-push     │
                              │  git clone + make   │
                              │  Flyway 镜像推送     │
                              └─────────┬──────────┘
                                        │
                              ┌─────────┴──────────┐
                              │  deploy-to-server   │
                              │  SSH 上传 compose   │
                              │  Flyway 数据库迁移   │
                              │  pull + up -d       │
                              └────────────────────┘
```

代码编译在 CI 阶段完成，服务器上只拉取镜像、启动容器，不再重复编译。

## 环境要求

- 本地：Docker Engine + Docker Compose v2（本地开发构建时）
- 服务器：Docker Engine + Docker Compose v2
- CI/CD：GitHub Actions（自动触发）

## 本地开发构建

### 1. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env`：

```env
# Git 仓库配置
GIT_REPO_URL=git@github.com:apEeach/DS_Course.git
GIT_SSH_KEY_PATH=/home/user/.ssh/id_ed25519

# Nginx 域名
SERVER_NAME=192.168.2.19

# 数据库配置
DB_HOST=db
DB_USER=root
DB_PASS=your_password
DB_NAME=mydb

# 控制开关
ENABLE_MYSQL=true
ENABLE_INIT_DB=false
```

| 变量 | 说明 |
|---|---|
| `GIT_REPO_URL` | 代码仓库地址 |
| `GIT_SSH_KEY_PATH` | SSH 私钥在**宿主机**上的绝对路径（私有仓库需要） |
| `SERVER_NAME` | Nginx server_name（域名或 IP） |
| `ENABLE_MYSQL` | `true` 启动内置 MySQL，`false` 使用外部数据库 |
| `ENABLE_INIT_DB` | `true` 执行 `init_db.sh` 初始化，`false` 跳过（使用 Flyway 管理数据库时设为 `false`） |
| `DB_HOST` | 数据库地址，使用内置 MySQL 时填 `db` |
| `DB_USER` / `DB_PASS` / `DB_NAME` | 数据库账号、密码、库名 |

### 2. 构建并启动

```bash
# 完整启动（内置 MySQL + App + Nginx）
docker compose --profile mysql up -d --build

# 不使用内置 MySQL（外部数据库）
docker compose up -d --build
```

> 构建时 Docker 会从 Git 仓库 clone 代码并编译，需要 SSH 认证（私有仓库需配置 `GIT_SSH_KEY_PATH` 挂载密钥）。

## 数据库管理

项目使用 **Flyway** 管理数据库版本，迁移脚本位于 `migrations/` 目录。

```bash
# 手动执行 Flyway 迁移（外部数据库）
docker run --rm \
  --network host \
  -v "$(pwd)/migrations:/flyway/sql" \
  flyway/flyway:10 \
  -url="jdbc:mysql://${DB_HOST}:3306/${DB_NAME}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai" \
  -user="${DB_USER}" \
  -password="${DB_PASS}" \
  -locations="filesystem:/flyway/sql" \
  migrate
```

> CI/CD 部署时会自动执行 Flyway 迁移，无需手动操作。

## CI/CD 自动化部署

推送到 `main` 分支时自动触发。

### GitHub Secrets 配置

| Secret | 说明 |
|---|---|
| `ALIYUN_REGISTRY` | 阿里云镜像仓库地址 |
| `ALIYUN_USERNAME` | 阿里云 ACR 用户名 |
| `ALIYUN_PASSWORD` | 阿里云 ACR 密码 |
| `GIT_SSH_PRIVATE_KEY` | 有远程仓库 clone 权限的 SSH 私钥内容 |
| `SSH_HOST` | 部署目标服务器 IP |
| `SSH_PRIVATE_KEY` | 服务器 SSH 私钥（用于登录部署） |

### CI 流程

1. **Build & Push**：从 `.env` 读取 `GIT_REPO_URL`，SSH agent 授权 clone 代码 → `make` 编译 → 推送到阿里云 ACR，同时推送 Flyway 镜像
2. **Deploy**：生成 `docker-compose.yml`（注入镜像名）和 `nginx.conf`（注入 `SERVER_NAME`）→ SCP 到服务器 → SSH 执行 Flyway 数据库迁移 → SSH 执行 `docker compose pull && up -d`
3. **`.env` 管理**：首次部署自动将仓库的 `.env` 部署到服务器，后续不覆盖服务器上已有的配置

### 服务器端

`.env` 首次部署自动生成，之后可在服务器上手动修改（如更改 `SERVER_NAME`、数据库地址等）。服务器只需执行：

```bash
cd /opt/myapp
docker compose pull
docker compose up -d
```

## 常用操作

| 操作 | 命令 |
|---|---|
| 查看日志 | `docker compose logs -f app` |
| 进入容器 | `docker exec -it my_cpp_dev bash` |
| 重启所有 | `docker compose restart` |
| 停止并删除容器 | `docker compose down` |
| 停止并删除全部（含 mysql） | `docker compose --profile mysql down` |
| 清理 mysql 数据 | `docker compose --profile mysql down -v && rm -rf mysql_data/` |

## 容器启动流程

```
app (entrypoint: entrypoint.sh → server) → nginx (等待 app 就绪后启动)
```

web 静态文件通过 Docker 命名卷 `web_data` 从 app 容器共享到 nginx，无需手动同步。

## 常见问题

### SSH key 挂载失败

确保 `.env` 中 `GIT_SSH_KEY_PATH` 是宿主机的**绝对路径**，且文件存在。

### Nginx 返回 403/404

web 静态文件通过 Docker 卷 `web_data` 从 app 容器 `/app/code/webSource` 共享。检查 app 容器是否正常启动。

### 端口冲突

80 或 8080 端口被占用时，检查是否有系统 nginx 或其他服务在运行：

```bash
# 查看端口占用
ss -tlnp | grep -E '80|8080'
# 停止系统 nginx
systemctl stop nginx
```
