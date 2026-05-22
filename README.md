# 课程培训平台

面向职业技能培训的 B2C 课程平台，支持微信小程序端用户购课、签到，以及后台管理系统进行课程运营和学员管理。

## 技术栈

- **后端**：C++（GCC）、MySQL 8.0、Go（支付服务）
- **数据库迁移**：Flyway / 手动 SQL 脚本
- **容器化**：Docker + Docker Compose
- **CI/CD**：GitHub Actions + 阿里云 ACR
- **反向代理**：Nginx

## 目录结构

```
├── .env                     # 环境变量配置（本地开发 & CI/CD 构建用）
├── docker/
│   ├── Dockerfile           # C++ 应用容器构建（Ubuntu 22.04，构建时 clone 代码 + make 编译）
│   ├── Dockerfile.pay       # Go 支付服务容器构建（Go 1.23，构建时 clone 代码 + 静态编译）
│   └── entrypoint.sh        # C++ 容器启动入口脚本（条件执行 init_db.sh + 启动 server）
├── docker-compose.yml       # 容器编排配置（app + pay + nginx + 可选 mysql）
├── nginx.conf               # Nginx 配置（server_name 通过环境变量注入）
├── migrations/
│   └── 1.sql                # 数据库初始化 SQL（用户 / 会话 / 第三方账号 / 验证码表）
├── docs/
│   ├── PRD.md               # 产品需求文档
│   └── db.md                # 数据库设计文档
└── .github/workflows/
    └── deploy.yml           # CI/CD 自动化构建 & 部署（支持多环境、多 ACR 推送）
```

## 部署架构

```
本地代码 ──push──> GitHub ──trigger──> CI/CD
                                        │
                              ┌─────────┴──────────┐
                              │  build-and-push     │
                              │  Ubuntu 22.04 编译   │ (C++, make)
                              │  Go 1.23 静态编译     │ (CGO_ENABLED=0)
                              │  推送到阿里云 ACR     │
                              │  (可选: 第二套 ACR)   │
                              └─────────┬──────────┘
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
          ┌─────────┴──────────┐                  ┌─────────┴──────────┐
          │ deploy-to-server-1 │                  │ deploy-to-server-2 │
          │ envsubst 生成配置   │                  │ envsubst 生成配置   │
          │ SCP 上传 + SSH 部署  │                  │ SCP 上传 + SSH 部署  │
          │ down → pull → up   │                  │ down → pull → up   │
          └────────────────────┘                  └────────────────────┘
```

代码编译在 CI 阶段完成（C++ 在 Ubuntu 22.04 镜像中编译，Go 在 golang:1.23 中静态编译），服务器上只拉取镜像、启动容器，不再重复编译。

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
PAY_GIT_REPO_URL=git@github.com:apEeach/DS_Course_Pay.git
GIT_SSH_KEY_PATH=/home/user/.ssh/id_ed25519

# 是否启动 mysql 容器（true / false）
ENABLE_MYSQL=false

# 是否执行数据库初始化脚本 init_db.sh（true / false）
ENABLE_INIT_DB=false

# 数据库配置
DB_HOST=db
DB_USER=root
DB_PASS=your_password
DB_NAME=mydb

# OSS 配置
OSS_ENDPOINT=test
OSS_ACCESS_KEY_ID=test
OSS_ACCESS_KEY_SECRET=test
OSS_BUCKET_NAME=test

# Nginx 域名
SERVER_NAME=192.168.2.19

# 支付服务配置
PAY_MODE=mock
MOCK_ORDER_STATE=NOTPAY

# 微信商户配置（PAY_MODE=real 时必填）
WECHAT_APPID=
WECHAT_MCH_ID=
WECHAT_SERIAL_NO=
WECHAT_API_V3_KEY=
WECHAT_CERT_PATH=/app/certs
WECHAT_NOTIFY_URL=

# 定时查单兜底配置
ENABLE_ORDER_CHECK=true
ORDER_PAYMENT_TIMEOUT_MINUTES=30
ORDER_CHECK_INTERVAL_SECONDS=300
```

| 变量 | 说明 |
|---|---|
| `GIT_REPO_URL` | C++ 代码仓库地址 |
| `PAY_GIT_REPO_URL` | Go 支付服务代码仓库地址 |
| `GIT_SSH_KEY_PATH` | SSH 私钥在**宿主机**上的绝对路径（私有仓库需要） |
| `ENABLE_MYSQL` | `true` 启动内置 MySQL（`profiles: mysql`），`false` 使用外部数据库 |
| `ENABLE_INIT_DB` | `true` 执行 `init_db.sh` 初始化，`false` 跳过（使用 Flyway 时建议设为 `false`） |
| `DB_HOST` | 数据库地址，使用内置 MySQL 时填 `db` |
| `DB_USER` / `DB_PASS` / `DB_NAME` | 数据库账号、密码、库名 |
| `SERVER_NAME` | Nginx server_name（域名或 IP） |
| `PAY_MODE` | `mock`（模拟）或 `real`（真实微信支付） |
| `MOCK_ORDER_STATE` | mock 查单返回状态（NOTPAY/SUCCESS/CLOSED/REVOKED） |
| `OSS_ENDPOINT` | 阿里云 OSS Endpoint 地址 |
| `OSS_ACCESS_KEY_ID` | 阿里云 OSS 访问密钥 ID |
| `OSS_ACCESS_KEY_SECRET` | 阿里云 OSS 访问密钥 Secret |
| `OSS_BUCKET_NAME` | 阿里云 OSS Bucket 名称 |
| `WECHAT_APPID` | 微信 AppID（`PAY_MODE=real` 时必填） |
| `WECHAT_MCH_ID` | 微信商户号（`PAY_MODE=real` 时必填） |
| `WECHAT_SERIAL_NO` | 商户证书序列号（`PAY_MODE=real` 时必填） |
| `WECHAT_API_V3_KEY` | APIv3 密钥（`PAY_MODE=real` 时必填） |
| `WECHAT_CERT_PATH` | 商户证书目录（容器内路径） |
| `WECHAT_NOTIFY_URL` | 微信支付回调地址 |
| `ENABLE_ORDER_CHECK` | 是否开启定时查单兜底（`true`/`false`） |
| `ORDER_PAYMENT_TIMEOUT_MINUTES` | 订单支付超时时间（分钟），超时后不再查询 |
| `ORDER_CHECK_INTERVAL_SECONDS` | 定时查单间隔（秒） |

### 2. 构建并启动

```bash
# 完整启动（内置 MySQL + C++ app + Go pay + Nginx）
docker compose --profile mysql up -d --build

# 不使用内置 MySQL（外部数据库）
docker compose up -d --build
```

> 构建时 Docker 会从 Git 仓库 clone 代码并编译，需要 SSH 认证（私有仓库需配置 SSH key）。
> C++ 镜像基于 Ubuntu 22.04，安装 build-essential、Boost、libmysqlclient-dev、libcurl、libssl 等依赖；Go 支付服务基于 golang:1.23 编译，最终运行镜像为 Alpine。

## 容器启动流程

```
app (entrypoint: entrypoint.sh)
  └─ 若 ENABLE_INIT_DB=true 且 init_db.sh 存在 → 执行初始化脚本
  └─ exec ./server 启动 C++ 服务（PID 1）
  ← 依赖 pay

pay (Go 支付服务，CGO_ENABLED=0 静态编译，直接启动)

nginx (depends_on app，启动后反向代理到 app:8080 和 pay:9090)

db (可选，profiles: mysql，MySQL 8.0，端口映射 3306)
```

web 静态文件通过 Docker 命名卷 `web_data` 从 app 容器 `/app/code/webSource` 共享到 nginx `/usr/share/nginx/web`，无需手动同步。

## 数据库初始化

项目通过 `migrations/1.sql` 管理数据库表结构，包含以下表：

| 表名 | 说明 |
|---|---|
| `user` | 用户信息表 |
| `session` | 用户会话表（关联 `user.id`） |
| `account` | 第三方账号绑定表（关联 `user.id`） |
| `verification` | 验证码 / 验证令牌表 |

初始化方式：

- **内置 MySQL**：通过 `init_db.sh` 脚本执行（需 `ENABLE_INIT_DB=true`）
- **外部数据库**：手动执行 `migrations/1.sql` 或使用 Flyway 等迁移工具
- **Flyway**：推荐生产环境使用，`migrations/` 目录下的 SQL 文件按版本顺序执行

## CI/CD 自动化部署

推送到 `main` 分支时自动触发。

### 多环境部署

在 `deploy.yml` 顶部设置 `DEPLOY_TARGET` 控制部署目标：

```yaml
env:
  ACR_NAMESPACE: sxd_server
  DEPLOY_TARGET: 1  # 1=只部署第一套, 2=只部署第二套, both=都部署
```

### GitHub Secrets 配置

| Secret | 说明 |
|---|---|
| `ALIYUN_REGISTRY` | 第一套阿里云 ACR 地址 |
| `ALIYUN_USERNAME` | 第一套 ACR 用户名 |
| `ALIYUN_PASSWORD` | 第一套 ACR 密码 |
| `GIT_SSH_PRIVATE_KEY` | 有远程仓库 clone 权限的 SSH 私钥 |
| `SSH_HOST` | 第一台部署服务器 IP |
| `SSH_PRIVATE_KEY` | 第一台服务器 SSH 私钥 |
| **可选第二套环境** | |
| `ALIYUN_REGISTRY_2` | 第二套阿里云 ACR 地址（不配置则跳过） |
| `ALIYUN_USERNAME_2` | 第二套 ACR 用户名 |
| `ALIYUN_PASSWORD_2` | 第二套 ACR 密码 |
| `SSH_HOST_2` | 第二台部署服务器 IP |
| `SSH_PRIVATE_KEY_2` | 第二台服务器 SSH 私钥 |

### CI 流程

1. **Build & Push**：
   - 从 `.env` 读取 `GIT_REPO_URL` 和 `PAY_GIT_REPO_URL`
   - SSH agent 授权 clone C++ 代码 → `make` 编译（Ubuntu 22.04 镜像，依赖 Boost、libmysqlclient-dev 等）→ 推送到 ACR
   - 克隆 Go 支付代码 → `CGO_ENABLED=0 go build` 静态编译 → 推送到 ACR
   - 镜像 tag 使用日期格式 `YYYYMMDD`，同时推送 `latest`
   - 如果配置了第二套 ACR，同时推送到第二套
2. **Deploy**：通过 `envsubst` 注入镜像地址生成 `docker-compose.yml`，注入域名生成 `nginx.conf` → SCP 到服务器 → SSH 执行 `docker compose down --volumes` 清理 → `docker compose pull` 拉新镜像 → `docker compose up -d` 启动
3. **`.env` 和 `nginx.conf` 管理**：首次部署自动上传到服务器 `/opt/myapp/`，后续不覆盖

### 服务器端

`.env` 和 `nginx.conf` 首次部署自动生成，之后可在服务器上手动修改（如更改 `SERVER_NAME`、数据库地址等）。修改后执行：

```bash
cd /opt/myapp
docker compose restart nginx  # 修改 nginx.conf 后重启
docker compose pull
docker compose up -d
```

## 常用操作

| 操作 | 命令 |
|---|---|
| 查看日志 | `docker compose logs -f app` 或 `docker compose logs -f pay` |
| 进入 C++ 容器 | `docker exec -it my_cpp_dev bash` |
| 进入 Go 支付容器 | `docker exec -it my_go_pay bash` |
| 健康检查（Go） | `curl http://localhost:9090/health` |
| 重启所有 | `docker compose restart` |
| 停止并删除容器 | `docker compose down` |
| 停止并删除全部（含 mysql） | `docker compose --profile mysql down` |
| 清理 mysql 数据 | `docker compose --profile mysql down -v && rm -rf mysql_data/` |

## Nginx 路由

| 路径 | 目标 | 说明 |
|---|---|---|
| `/` | 静态文件 (`/usr/share/nginx/web/html`) | index.html |
| `/api` | C++ 后端 (`app:8080`) | 通过 upstream `crow_backend` 转发 |
| `/pay/notify` | Go 支付服务微信回调 (`my_go_pay:9090`) | 通过 upstream `go_pay` 转发，`client_max_body_size 1m` |
| `/pay/mockOrderQuery/` | Go 支付服务查单接口 (`my_go_pay:9090`) | Mock 查单，本地开发用 |

## 常见问题

### SSH key 挂载失败

确保 SSH key 绑定的 GitHub 账号对 `DS_Course` 和 `DS_Course_Pay` 两个仓库都有 clone 权限。

### Go 支付服务启动失败

检查 `/pay_service` 二进制是否存在：
```bash
docker logs my_go_pay
```
如果报 `no such file or directory`，通常是 CI 构建时没有加 `CGO_ENABLED=0` 静态编译。

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

### `nginx.conf` 或 `.env` 不生效

这两个文件在**首次部署**时上传到服务器，后续 CI/CD 不会覆盖。如需更新，可在服务器上直接修改 `/opt/myapp/nginx.conf` 和 `/opt/myapp/.env`，然后重启对应容器。
