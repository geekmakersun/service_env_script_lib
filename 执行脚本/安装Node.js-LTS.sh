#!/bin/bash

# Node.js LTS 安装脚本

# 颜色定义
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}Node.js LTS 安装脚本${NC}"
echo -e "${GREEN}=======================================${NC}"

# 检查 curl 是否安装
if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误：curl 未安装，请先安装 curl。${NC}"
    exit 1
fi

# 安装 nvm
echo -e "${YELLOW}正在安装 nvm...${NC}"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# 重新加载 bashrc 文件
echo -e "${YELLOW}重新加载 bashrc 文件...${NC}"
source /root/.bashrc

# 安装最新 LTS 版本的 Node.js
echo -e "${YELLOW}正在安装最新 LTS 版本的 Node.js...${NC}"
nvm install --lts

# 设置全局默认版本
echo -e "${YELLOW}设置全局默认版本...${NC}"
nvm alias default node

# 验证安装
echo -e "${YELLOW}验证安装...${NC}"
echo -e "Node.js 版本：$(node -v)"
echo -e "npm 版本：$(npm -v)"

echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}=======================================${NC}"
echo -e "${YELLOW}提示：如果在新终端中使用 Node.js，请确保 bashrc 文件已正确配置。${NC}"