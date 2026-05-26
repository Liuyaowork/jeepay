#!/usr/bin/env bash
# ============================================================================
# Jeepay Docker 容器入口脚本
# 负责：初始化配置目录、检查挂载卷、启动 Java 应用
# ============================================================================
set -euo pipefail

# 应用工作目录
APP_HOME="/jeepayhomes/service"
APP_DIR="${APP_HOME}/app"
LOGS_DIR="${APP_HOME}/logs"
UPLOADS_DIR="${APP_HOME}/uploads"
CONF_DIR="${APP_HOME}/conf"

# 创建必要的目录
mkdir -p "${APP_DIR}" "${LOGS_DIR}" "${UPLOADS_DIR}" "${CONF_DIR}"

# 如果挂载了 application.yml 到 conf 目录，则链接到 app 目录
# 支持两种挂载方式：
#   1. 直接挂载到 /jeepayhomes/service/app/application.yml（旧方式）
#   2. 挂载到 /jeepayhomes/service/conf/application.yml（新推荐方式）
if [ -f "${CONF_DIR}/application.yml" ] && [ ! -f "${APP_DIR}/application.yml" ]; then
  cp "${CONF_DIR}/application.yml" "${APP_DIR}/application.yml"
  echo "[入口脚本] 已从 conf/ 复制 application.yml"
fi

# 检查 JAR 包是否存在
JAR_FILE="${APP_DIR}/${APP_NAME:-app}.jar"
if [ ! -f "${JAR_FILE}" ]; then
  # 尝试查找 jar
  JAR_FILE=$(find "${APP_DIR}" -name "*.jar" -type f 2>/dev/null | head -1)
fi

if [ -z "${JAR_FILE}" ] || [ ! -f "${JAR_FILE}" ]; then
  echo "[错误] 未找到 JAR 包！请确保构建产物已复制到 ${APP_DIR}"
  exit 1
fi

echo "[入口脚本] 启动应用: $(basename "${JAR_FILE}")"
echo "[入口脚本] 日志目录: ${LOGS_DIR}"
echo "[入口脚本] 上传目录: ${UPLOADS_DIR}"
echo ""

# 启动 Spring Boot 应用
# 配置外部配置路径，优先加载挂载的 application.yml
exec java \
  -jar "${JAR_FILE}" \
  "--spring.config.additional-location=file:${APP_DIR}/application.yml" \
  "$@"
