#!/usr/bin/env bash
# ============================================================================
# Jeepay 远程部署脚本
# 在目标服务器上执行：登录阿里云 ACR → 拉取最新镜像 → 停止旧容器 → 启动新容器
# 使用方式：
#   # 先登录阿里云 ACR
#   docker login ${ALIYUN_REGISTRY_URL:-registry.cn-hangzhou.aliyuncs.com}
#   # 然后执行部署
#   bash deploy.sh
# ============================================================================
set -euo pipefail

# ---- 配置区 ----
PROJECT_DIR="${HOME}/jeepay"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
ENV_FILE="${PROJECT_DIR}/.env"
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 阿里云 ACR 配置（可从环境变量读取，也可在此填写）
ALIYUN_REGISTRY_URL="${ALIYUN_REGISTRY_URL:-registry.cn-hangzhou.aliyuncs.com}"
ALIYUN_NAMESPACE="${ALIYUN_NAMESPACE:-jeepay}"

# Docker Compose 命令（兼容旧版 docker-compose 和 新版 docker compose）
if command -v docker-compose &>/dev/null; then
  COMPOSE_CMD="docker-compose"
elif docker compose version &>/dev/null; then
  COMPOSE_CMD="docker compose"
else
  echo "[错误] 未找到 docker-compose 或 docker compose 命令！"
  exit 1
fi

# ---- 前置检查 ----
echo "========================================"
echo " Jeepay 部署脚本 v1.0"
echo " 日期: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# 检查 Docker
if ! docker info &>/dev/null; then
  echo "[错误] Docker 未运行或当前用户无权限访问！"
  exit 1
fi

# 检查配置文件
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "[错误] 未找到 docker-compose.yml！"
  echo "请确保 ${COMPOSE_FILE} 存在。"
  exit 1
fi

# ---- 阿里云 ACR 登录检查 ----
echo ""
echo "[0/5] 检查阿里云 ACR 登录状态..."
# 尝试拉取一个不存在的镜像来检查认证状态
if ! docker pull "${ALIYUN_REGISTRY_URL}/${ALIYUN_NAMESPACE}/jeepay-payment:latest" 2>&1 | grep -q "Pulling from"; then
  # 检查是否未登录（返回包含 "unauthorized" 或 "denied" 的错误）
  if docker pull "${ALIYUN_REGISTRY_URL}/${ALIYUN_NAMESPACE}/jeepay-payment:latest" 2>&1 | grep -qiE "unauthorized|denied|authentication"; then
    echo "[警告] 阿里云 ACR 未登录！请先执行："
    echo "  docker login ${ALIYUN_REGISTRY_URL}"
    echo ""
    # 不阻塞部署流程，后续 pull 也会提示
  else
    echo "  ✓ ACR 登录状态正常"
  fi
else
  echo "  ✓ ACR 登录状态正常"
fi

# ---- 备份当前状态 ----
echo ""
echo "[1/5] 备份当前部署状态..."
mkdir -p "$BACKUP_DIR"
if [ -f "$COMPOSE_FILE" ]; then
  cp "$COMPOSE_FILE" "${BACKUP_DIR}/docker-compose.${TIMESTAMP}.yml"
  echo "  ✓ docker-compose.yml 已备份"
fi
if [ -f "$ENV_FILE" ]; then
  cp "$ENV_FILE" "${BACKUP_DIR}/.env.${TIMESTAMP}"
  echo "  ✓ .env 已备份"
fi

# ---- 拉取最新镜像 ----
echo ""
echo "[2/5] 拉取最新 Docker 镜像..."
$COMPOSE_CMD -f "$COMPOSE_FILE" pull 2>&1 | sed 's/^/  /'
echo "  ✓ 镜像拉取完成"

# ---- 停止旧容器 ----
echo ""
echo "[3/5] 停止旧容器..."
$COMPOSE_CMD -f "$COMPOSE_FILE" down 2>&1 | sed 's/^/  /' || true
echo "  ✓ 旧容器已停止"

# ---- 清理旧资源 ----
echo ""
echo "[4/5] 清理旧镜像和未使用资源..."
docker image prune -f --filter "until=24h" 2>&1 | sed 's/^/  /' || true
echo "  ✓ 清理完成"

# ---- 启动新容器 ----
echo ""
echo "[5/5] 启动新容器..."
$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d 2>&1 | sed 's/^/  /'

# ---- 检查服务状态 ----
echo ""
echo "========================================"
echo " 服务状态检查"
echo "========================================"
# 等待几秒让服务初始化
sleep 5
$COMPOSE_CMD -f "$COMPOSE_FILE" ps

echo ""
echo "========================================"
echo " 部署完成！"
echo " 备份位置: ${BACKUP_DIR}/"
echo " 如有问题可回滚:"
echo "   $COMPOSE_CMD -f ${BACKUP_DIR}/docker-compose.${TIMESTAMP}.yml up -d"
echo "========================================"
