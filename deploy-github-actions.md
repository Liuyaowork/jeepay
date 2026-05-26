# Jeepay GitHub Actions + Docker 部署方案（阿里云镜像加速版）

## 概述

本方案使用 **GitHub Actions** 实现 Jeepay 的自动化构建和 Docker 部署，**镜像全部使用阿里云 ACR（容器镜像服务）**，解决国内网络无法直接访问 Docker Hub 的问题。

包含三个工作流：

| 工作流文件 | 触发方式 | 功能 |
|-----------|---------|------|
| `.github/workflows/ci-cd.yml` | 推送 main/master、创建 v* 标签、手动 | 完整 CI/CD：编译 → 构建镜像 → 推送到阿里云 ACR → 部署 |
| `.github/workflows/docker-build.yml` | 手动触发 | 仅构建 Docker 镜像并推送到阿里云 ACR |
| `.github/workflows/ci.yml` | 推送 master/dev、PR | 原项目自带轻量 CI（保留不变） |

## 阿里云 ACR 镜像体系

本项目的镜像分为两部分：

### 基础设施镜像（阿里云公共镜像仓库）
由本项目预先同步到阿里云，无需自行管理：

| 镜像 | 阿里云地址 |
|------|-----------|
| MySQL 8.0 | `registry.cn-hangzhou.aliyuncs.com/jeequan/mysql:8.0` |
| Redis 6.2.14 | `registry.cn-hangzhou.aliyuncs.com/jeequan/redis:6.2.14` |
| RocketMQ 5.3.1 | `registry.cn-hangzhou.aliyuncs.com/jeequan/rocketmq:5.3.1` |
| Eclipse Temurin JRE 17 | `registry.cn-hangzhou.aliyuncs.com/jeequan/eclipse-temurin:17-jre` |

### 业务镜像（你的阿里云 ACR 命名空间）
由 GitHub Actions 构建并推送到你的阿里云 ACR 仓库：

| 镜像 | 地址格式 |
|------|---------|
| 支付网关 | `${ALIYUN_REGISTRY_URL}/${ALIYUN_NAMESPACE}/jeepay-payment:latest` |
| 运营平台 | `${ALIYUN_REGISTRY_URL}/${ALIYUN_NAMESPACE}/jeepay-manager:latest` |
| 商户平台 | `${ALIYUN_REGISTRY_URL}/${ALIYUN_NAMESPACE}/jeepay-merchant:latest` |

## 配置步骤

### 1. 阿里云 ACR 准备

1. 登录 [阿里云容器镜像服务](https://cr.console.aliyun.com)
2. 创建命名空间（如 `jeepay`）
3. 创建镜像仓库（jeepay-payment、jeepay-manager、jeepay-merchant），类型选择「私有」
4. 设置固定密码：前往 **访问凭证** 页面设置密码

### 2. GitHub Secrets 配置

在 GitHub 仓库 → **Settings** → **Secrets and variables** → **Actions** 中添加以下 Secrets：

| Secret 名称 | 说明 | 是否必填 |
|------------|------|---------|
| `ALIYUN_REGISTRY_URL` | 阿里云 ACR 地址（默认 `registry.cn-hangzhou.aliyuncs.com`） | ✅ 必填 |
| `ALIYUN_REGISTRY_USER` | 阿里云 ACR 用户名（格式：`阿里云账号`@`容器镜像服务实例ID`） | ✅ 必填 |
| `ALIYUN_REGISTRY_PASSWORD` | 阿里云 ACR 固定密码 | ✅ 必填 |
| `ALIYUN_NAMESPACE` | 阿里云 ACR 命名空间（如 `jeepay`） | ✅ 必填 |
| `DEPLOY_HOST` | 部署服务器 IP 或域名 | 可选（自动部署时需要） |
| `DEPLOY_USER` | 部署服务器 SSH 用户名 | 可选 |
| `DEPLOY_SSH_KEY` | 部署服务器 SSH 私钥 | 可选 |
| `DEPLOY_PORT` | SSH 端口（默认 22） | 可选 |
| `DEPLOY_SSH_PASSPHRASE` | SSH 密钥口令 | 可选 |

> **注意**：ALIYUN_REGISTRY_USER 格式为 `账号@实例ID`，可在阿里云 ACR 控制台 → 访问凭证中查看。

### 3. 手动触发工作流

在 GitHub 仓库 → **Actions** → 选择对应的 Workflow → **Run workflow**。

**CI/CD 工作流** 可以指定：
- 是否同时执行远程部署（勾选 `deploy`）

**Docker 构建工作流** 可以指定：
- `modules`：要构建的模块（留空构建全部）
- `tags`：自定义镜像标签

### 4. 服务器 Docker 配置（阿里云镜像加速）

```bash
# 1. 安装 Docker（Ubuntu/Debian）
curl -fsSL https://get.docker.com | bash

# 2. 安装 Docker Compose
sudo apt install docker-compose-plugin

# 3. 配置 Docker 镜像加速（阿里云）
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "https://registry.cn-hangzhou.aliyuncs.com",
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# 4. 重启 Docker
sudo systemctl restart docker

# 5. 创建项目目录
# epay 用户家目录下的部署目录（epay 有写权限，无需 sudo）
mkdir -p ~/jeepay
mkdir -p ~/jeepay/data/{mysql,redis,logs,uploads,rocketmq}

# 6. 登录阿里云 ACR
docker login registry.cn-hangzhou.aliyuncs.com
```

### 5. 首次手动部署

```bash
# 将项目复制到服务器
cd ~/jeepay

# 复制配置
cp .env.prod .env
# 编辑 .env 修改数据库密码等配置
vim .env

# 启动所有服务
docker compose --env-file .env -f docker-compose.prod.yml up -d

# 查看状态
docker compose -f docker-compose.prod.yml ps
```

### 6. 后续更新（GitHub Actions 自动部署）

当推送代码到 `main/master` 分支或打 `v*` 标签时，CI/CD 工作流会自动：
1. Maven 编译打包（使用阿里云 Maven 镜像加速依赖下载）
2. 构建 Docker 镜像并推送到阿里云 ACR
3. 通过 SSH 部署到服务器

## Maven 国内镜像加速

工作流中已配置阿里云 Maven 镜像 `https://maven.aliyun.com/repository/public`，加速依赖下载。

如需在本地开发时使用，在 `~/.m2/settings.xml` 中添加：

```xml
<mirror>
  <id>aliyun-maven</id>
  <mirrorOf>central</mirrorOf>
  <name>阿里云公共仓库</name>
  <url>https://maven.aliyun.com/repository/public</url>
</mirror>
```

## 挂载卷说明

所有 Java 服务都声明了以下 3 个挂载卷：

| 容器内路径 | 宿主机路径 | 用途 | 说明 |
|-----------|-----------|------|------|
| `/jeepayhomes/service/logs` | `${DEPLOY_BASE}/logs/{模块名}/` | 应用日志 | **必须挂载**，否则日志随容器销毁 |
| `/jeepayhomes/service/uploads` | `${DEPLOY_BASE}/uploads/` | 上传文件/证书 | **必须挂载**，否则上传文件会丢失 |
| `/jeepayhomes/service/conf` | `./conf/{模块名}/application.yml` | 外部配置 | 推荐挂载，方便修改无需重建镜像 |

## 本地开发快速构建

```bash
# 1. 配置 Maven 阿里云镜像（~/.m2/settings.xml），然后编译
mvn clean package -DskipTests

# 2. 启动所有服务
docker compose -f docker-compose.local.yml up -d

# 3. 查看日志
docker compose -f docker-compose.local.yml logs -f
```

## 工作流架构图

```mermaid
flowchart LR
    A[推送代码] --> B[GitHub Actions 触发]
    B --> C[Maven 编译<br/>阿里云镜像加速]
    C --> D[Docker 构建<br/>基础镜像:阿里云ACR]
    D --> E[推送到阿里云ACR]
    E --> F[SSH 远程部署]
    F --> G[登录阿里云ACR]
    G --> H[拉取镜像<br/>阿里云内网加速]
    H --> I[停止旧容器]
    I --> J[启动新容器]
```
