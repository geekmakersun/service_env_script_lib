#!/bin/bash

# Node.js LTS 安装和卸载脚本

# 颜色定义
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

NVM_DIR="/opt/nvm"

# 显示帮助信息
show_help() {
    echo -e "${GREEN}=======================================${NC}"
    echo -e "Node.js LTS 安装和卸载脚本${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo -e "用法: $0 [选项]"
    echo -e ""
    echo -e "选项:"
    echo -e "  -i, --install     - 安装 Node.js LTS 版本"
    echo -e "  -u, --uninstall   - 卸载 Node.js 和 nvm"
    echo -e "  -h, --help        - 显示此帮助信息"
    echo -e ""
}

# 安装 Node.js LTS
install_node() {
    echo -e "${GREEN}=======================================${NC}"
    echo -e "Node.js LTS 安装${NC}"
    echo -e "${GREEN}=======================================${NC}"

    # 检查 curl 是否安装
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}错误：curl 未安装，请先安装 curl。${NC}"
        exit 1
    fi

    # 安装 nvm 到 /opt/nvm
    echo -e "${YELLOW}正在安装 nvm 到 ${NVM_DIR}...${NC}"
    if [[ ! -d "${NVM_DIR}" ]]; then
        mkdir -p "${NVM_DIR}"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash -s -- --no-install
        cp -r "$HOME/.nvm/"* "${NVM_DIR}/"
        chown -R git:git "${NVM_DIR}"
        chmod -R 755 "${NVM_DIR}"
        echo -e "${GREEN}nvm 安装成功${NC}"
    else
        echo -e "${YELLOW}nvm 已安装，跳过安装步骤${NC}"
    fi

    # 安装最新 LTS 版本的 Node.js
    echo -e "${YELLOW}正在安装最新 LTS 版本的 Node.js...${NC}"
    bash -c "source ${NVM_DIR}/nvm.sh && nvm install --lts && nvm use --lts && nvm alias default node"

    # 创建系统级符号链接
    echo -e "${YELLOW}创建系统级符号链接...${NC}"
    local node_version=$(bash -c "source ${NVM_DIR}/nvm.sh && nvm current")
    local node_bin_dir="${NVM_DIR}/versions/node/${node_version}/bin"
    
    if [[ -d "${node_bin_dir}" ]]; then
        ln -sf "${node_bin_dir}/node" /usr/local/bin/node
        ln -sf "${node_bin_dir}/npm" /usr/local/bin/npm
        ln -sf "${node_bin_dir}/npx" /usr/local/bin/npx
        chmod +x /usr/local/bin/node /usr/local/bin/npm /usr/local/bin/npx
        echo -e "${GREEN}符号链接创建成功${NC}"
    else
        echo -e "${RED}错误：Node.js 可执行文件目录未找到${NC}"
    fi

    # 为 git 用户配置 nvm
    echo -e "${YELLOW}为 git 用户配置 nvm...${NC}"
    if [[ -f "/home/git/.bashrc" ]]; then
        if ! grep -q "nvm.sh" "/home/git/.bashrc"; then
            echo "" >> /home/git/.bashrc
            echo "# Load NVM" >> /home/git/.bashrc
            echo "export NVM_DIR=\"${NVM_DIR}\"" >> /home/git/.bashrc
            echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"  # This loads nvm" >> /home/git/.bashrc
            echo "[ -s \"\$NVM_DIR/bash_completion\" ] && \. \"\$NVM_DIR/bash_completion\"  # This loads nvm bash_completion" >> /home/git/.bashrc
            chown git:git /home/git/.bashrc
            echo -e "${GREEN}git 用户 nvm 配置成功${NC}"
        else
            echo -e "${YELLOW}git 用户 nvm 配置已存在，跳过配置步骤${NC}"
        fi
    fi

    # 验证安装
    echo -e "${YELLOW}验证安装...${NC}"
    if command -v node &> /dev/null; then
        echo -e "Node.js 版本：$(node -v)"
        echo -e "npm 版本：$(npm -v)"
    else
        echo -e "${RED}错误：Node.js 命令未找到${NC}"
    fi

    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}安装完成！${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${YELLOW}提示：Node.js 已安装到 ${NVM_DIR}${NC}"
}

# 卸载 Node.js 和 nvm
uninstall_node() {
    echo -e "${GREEN}=======================================${NC}"
    echo -e "Node.js 和 nvm 卸载${NC}"
    echo -e "${GREEN}=======================================${NC}"

    # 移除系统级符号链接
    echo -e "${YELLOW}移除系统级符号链接...${NC}"
    rm -f /usr/local/bin/node /usr/local/bin/npm /usr/local/bin/npx
    echo -e "${GREEN}符号链接移除成功${NC}"

    # 移除 nvm 目录
    echo -e "${YELLOW}移除 nvm 目录...${NC}"
    if [[ -d "${NVM_DIR}" ]]; then
        rm -rf "${NVM_DIR}"
        echo -e "${GREEN}nvm 目录移除成功${NC}"
    else
        echo -e "${YELLOW}nvm 目录不存在，跳过移除步骤${NC}"
    fi

    # 清理 git 用户的 nvm 配置
    echo -e "${YELLOW}清理 git 用户的 nvm 配置...${NC}"
    if [[ -f "/home/git/.bashrc" ]]; then
        sed -i '/nvm.sh/d' /home/git/.bashrc
        sed -i '/NVM_DIR/d' /home/git/.bashrc
        sed -i '/Load NVM/d' /home/git/.bashrc
        chown git:git /home/git/.bashrc
        echo -e "${GREEN}git 用户 nvm 配置清理成功${NC}"
    fi

    # 清理 root 用户的 nvm 配置
    echo -e "${YELLOW}清理 root 用户的 nvm 配置...${NC}"
    if [[ -f "/root/.bashrc" ]]; then
        sed -i '/nvm.sh/d' /root/.bashrc
        sed -i '/NVM_DIR/d' /root/.bashrc
        sed -i '/Load NVM/d' /root/.bashrc
        echo -e "${GREEN}root 用户 nvm 配置清理成功${NC}"
    fi

    # 移除可能的残留目录
    echo -e "${YELLOW}移除残留目录...${NC}"
    rm -rf /home/git/.nvm /root/.nvm
    echo -e "${GREEN}残留目录移除成功${NC}"

    # 验证卸载
    echo -e "${YELLOW}验证卸载...${NC}"
    if command -v node &> /dev/null; then
        echo -e "${RED}警告：Node.js 命令仍然存在${NC}"
        echo -e "${YELLOW}尝试查找并移除...${NC}"
        which node | xargs rm -f 2>/dev/null
        if command -v node &> /dev/null; then
            echo -e "${RED}错误：无法移除 Node.js 命令${NC}"
        else
            echo -e "${GREEN}Node.js 命令已成功移除${NC}"
        fi
    else
        echo -e "${GREEN}Node.js 命令已成功移除${NC}"
    fi

    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}卸载完成！${NC}"
    echo -e "${GREEN}=======================================${NC}"
}

# 主函数
main() {
    # 处理命令行选项
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    case "$1" in
        -i|--install)
            install_node
            ;;
        -u|--uninstall)
            uninstall_node
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}错误：未知选项 $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
