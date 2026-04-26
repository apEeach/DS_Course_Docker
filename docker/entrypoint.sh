#!/bin/bash
# =============================================================================
# Docker App Entrypoint Script
# 容器启动时自动执行：配置 SSH → Clone 代码 → 拉取子模块 → 编译 → 启动服务
# =============================================================================

# 代码克隆目标目录（对应 docker-compose.yml 中的 volume 挂载点 ./code:/app/code）
CLONE_DIR="/app/code"
# Git 仓库地址，通过 docker-compose.yml 的环境变量 GIT_REPO_URL 传入
REPO_URL="$GIT_REPO_URL"

# =============================================================================
# Step 0: 打印配置摘要
# =============================================================================
echo "========================================"
echo "  Entrypoint Configuration"
echo "========================================"
echo "  GIT_REPO_URL:   $REPO_URL"
echo "  ENABLE_INIT_DB: $ENABLE_INIT_DB"
echo "  DB_HOST:        $DB_HOST"
echo "========================================"

# =============================================================================
# Step 1: SSH 配置
# 当仓库地址使用 git@ 协议（私有仓库）时，配置 SSH 认证
# 宿主机上的 SSH 私钥通过 volume 挂载到 /root/.ssh/id_ed25519
# =============================================================================
if echo "$REPO_URL" | grep -q "^git@"; then
  SSH_KEY="/root/.ssh/id_ed25519"

  # 检查 SSH key 是否存在且非空文件
  if [ ! -s "$SSH_KEY" ]; then
    echo ""
    echo "=============================================="
    echo "  [ERROR] SSH key missing!"
    echo "=============================================="
    echo "  The repository uses git@ protocol, but no SSH"
    echo "  private key was mounted."
    echo ""
    echo "  Please set GIT_SSH_KEY_PATH in .env to the"
    echo "  absolute path of your SSH private key on the"
    echo "  host machine."
    echo ""
    echo "  Example:"
    echo "    GIT_SSH_KEY_PATH=/home/user/.ssh/id_ed25519"
    echo "=============================================="
    echo ""
    exit 1
  fi

  # 创建 SSH 目录并设置权限
  mkdir -p /root/.ssh
  chmod 600 "$SSH_KEY"

  # 将 GitHub 的 host key 添加到 known_hosts（避免首次连接时的交互提示）
  ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null

  # 设置 git 使用的 SSH 命令，指定私钥路径并跳过 host key 检查
  export GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=no"
  echo "[entrypoint] SSH key mounted, using git@ protocol"
fi

# =============================================================================
# Step 2: Git Clone（包含子模块 --recursive）
# 如果 /app/code 下已有 .git 目录，则执行 pull 更新
# 否则先 clone 到 /tmp，再移动到挂载的 /app/code（避免直接 clone 到挂载点报错）
# =============================================================================
if [ -d "$CLONE_DIR/.git" ]; then
  # 仓库已存在，拉取最新代码
  echo "[entrypoint] Repo already exists, updating and pulling submodules..."
  cd "$CLONE_DIR" && git pull

  # 尝试更新子模块，如果失败则清理损坏的子模块后重试
  if ! git submodule update --init --recursive 2>/dev/null; then
    echo "[entrypoint] Submodule update failed, cleaning corrupted submodules..."
    # 找出所有未初始化的子模块（status 以 - 开头表示未初始化），逐个清理后重新拉取
    git submodule status --recursive 2>&1 | grep '^-' | awk '{print $2}' | while read mod; do
      echo "  Re-cloning $mod..."
      git submodule deinit -f "$mod" 2>/dev/null || true
      rm -rf "$mod"
    done
    git submodule update --init --recursive
  fi
else
  # 首次启动，clone 仓库到临时目录（因为 /app/code 是挂载点不能直接 clone）
  echo "[entrypoint] Cloning $REPO_URL -> /tmp/repo ..."
  git clone --recursive "$REPO_URL" /tmp/repo
  # 将 clone 的内容移动到挂载目录，包括隐藏文件（如 .git、.gitmodules）
  mv /tmp/repo/* /tmp/repo/.* "$CLONE_DIR" 2>/dev/null || true
  rm -rf /tmp/repo
fi

echo "[entrypoint] Code ready at $CLONE_DIR"

# =============================================================================
# Step 3: 编译项目
# 进入代码目录执行 make，依赖 Makefile 中定义的编译规则
# =============================================================================
cd "$CLONE_DIR"
echo "[entrypoint] Running make..."
make
echo "[entrypoint] Build done."

# =============================================================================
# Step 4: 执行初始化脚本（如果存在且 ENABLE_INIT_DB=true）
# init_db.sh 用于执行数据库建表、数据迁移等初始化操作
# 仅在使用数据库（ENABLE_MYSQL=true 或自有数据库）时才有意义
# =============================================================================
if [ "$ENABLE_INIT_DB" = "true" ] && [ -f "init_db.sh" ]; then
  echo "[entrypoint] Running init_db.sh..."
  bash init_db.sh
  echo "[entrypoint] init_db.sh done."
else
  echo "[entrypoint] init_db.sh skipped (ENABLE_INIT_DB=$ENABLE_INIT_DB or file not found)"
fi

# =============================================================================
# Step 5: 启动服务
# 使用 exec 替换当前 shell，使 server 成为 PID 1 主进程
# 这样 server 的日志直接输出到 docker logs，且信号（如 SIGTERM）能正确传递
# 查看日志：docker logs -f my_cpp_dev
# 进入容器：docker exec -it my_cpp_dev bash
# =============================================================================
echo "[entrypoint] Starting server..."
exec ./server
