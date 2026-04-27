#!/bin/bash
# 本地开发环境 Flyway 迁移脚本
# 用法: ./flyway-migrate.sh
# 前提: Docker MySQL 容器已启动且正在运行

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 从 .env 加载配置
if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo "Error: .env file not found"
  exit 1
fi

DB_PORT="${DB_PORT:-3306}"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "Error: migrations directory not found"
  exit 1
fi

echo "Running Flyway migration against localhost:${DB_PORT}/${DB_NAME} ..."

# 拉取 Flyway 镜像（本地可能不存在）
docker pull flyway/flyway:latest

# 运行 Flyway Docker 执行迁移（一次性容器，完成后自动退出）
docker run --rm \
  --network host \
  -v "$MIGRATIONS_DIR:/flyway/sql" \
  flyway/flyway:latest \
  -url="jdbc:mysql://localhost:${DB_PORT}/${DB_NAME}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai" \
  -user="${DB_USER}" \
  -password="${DB_PASS}" \
  -locations="filesystem:/flyway/sql" \
  migrate

echo "Migration completed."
