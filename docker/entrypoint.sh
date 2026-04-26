#!/bin/bash
# =============================================================================
# Docker App Entrypoint Script
# 代码和编译已在构建阶段完成，容器启动时直接初始化数据库并运行服务
# =============================================================================

cd /app/code

# =============================================================================
# Step 1: 打印配置摘要
# =============================================================================
echo "========================================"
echo "  Entrypoint Configuration"
echo "========================================"
echo "  ENABLE_INIT_DB: $ENABLE_INIT_DB"
echo "  DB_HOST:        $DB_HOST"
echo "========================================"

# =============================================================================
# Step 2: 执行初始化脚本（如果存在且 ENABLE_INIT_DB=true）
# =============================================================================
if [ "$ENABLE_INIT_DB" = "true" ] && [ -f "init_db.sh" ]; then
  echo "[entrypoint] Running init_db.sh..."
  bash init_db.sh
  echo "[entrypoint] init_db.sh done."
else
  echo "[entrypoint] init_db.sh skipped (ENABLE_INIT_DB=$ENABLE_INIT_DB or file not found)"
fi

# =============================================================================
# Step 3: 启动服务
# 使用 exec 替换当前 shell，使 server 成为 PID 1 主进程
# 这样 server 的日志直接输出到 docker logs，且信号（如 SIGTERM）能正确传递
# 查看日志：docker logs -f my_cpp_dev
# 进入容器：docker exec -it my_cpp_dev bash
# =============================================================================
echo "[entrypoint] Starting server..."
exec ./server
