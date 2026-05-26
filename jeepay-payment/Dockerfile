#
#   jeepay-payment（支付网关）Java 程序镜像构建脚本
#
#   挂载卷说明（使用 Docker 时务必挂载以下路径，避免数据丢失）：
#     - /jeepayhomes/service/logs      ：应用日志（必须挂载）
#     - /jeepayhomes/service/uploads   ：上传文件/证书（必须挂载）
#     - /jeepayhomes/service/conf      ：外部配置文件（推荐挂载）
#
#   使用示例：
#     docker run -d \
#       -v /宿主机路径/logs/payment:/jeepayhomes/service/logs \
#       -v /宿主机路径/uploads:/jeepayhomes/service/uploads \
#       -v /宿主机路径/conf/payment/application.yml:/jeepayhomes/service/conf/application.yml \
#       -p 9216:9216 \
#       jeepay-payment:latest
#

#
# 基础镜像说明（国内网络优化）：
#   - 默认使用阿里云 ACR 镜像仓库，国内拉取速度快
#   - 如需使用其他镜像，可通过构建参数覆盖：
#     docker build --build-arg BASE_IMAGE=eclipse-temurin:17-jre ...
#
ARG BASE_IMAGE=registry.cn-hangzhou.aliyuncs.com/jeequan/eclipse-temurin:17-jre
FROM ${BASE_IMAGE}

LABEL maintainer="Terrfly"
LABEL org.opencontainers.image.title="Jeepay 支付网关"
LABEL org.opencontainers.image.description="Jeepay 计全支付系统 - 支付统一网关"
LABEL org.opencontainers.image.url="https://www.jeequan.com"
LABEL org.opencontainers.image.source="https://github.com/jeequan/jeepay"
LABEL org.opencontainers.image.version="3.2.0"

ENV LANG=C.UTF-8
ENV TZ=Asia/Shanghai

EXPOSE 9216

# 声明挂载卷 —— 生产部署时务必在宿主机挂载持久化
VOLUME ["/jeepayhomes/service/logs", "/jeepayhomes/service/uploads", "/jeepayhomes/service/conf"]

RUN mkdir -p /jeepayhomes/service/app \
    /jeepayhomes/service/logs \
    /jeepayhomes/service/uploads \
    /jeepayhomes/service/conf

COPY ./target/jeepay-payment.jar /jeepayhomes/service/app/jeepay-payment.jar

WORKDIR /jeepayhomes/service/app

# 支持多层配置覆盖：conf 目录 > app 目录 > jar 内部默认配置
CMD ["java", \
     "-jar", "jeepay-payment.jar", \
     "--spring.config.additional-location=file:/jeepayhomes/service/conf/application.yml,file:/jeepayhomes/service/app/application.yml"]

# 端口探测，不依赖 curl/wget 等外部工具
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD bash -c 'echo > /dev/tcp/localhost/9216'
