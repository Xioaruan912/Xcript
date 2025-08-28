# 安装 docker
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun

# 安装 docker compose 插件
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://ghproxy.com/https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-x86_64 \
  -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

# 测试
docker compose version
