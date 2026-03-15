#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODSECURITY_VERSION="${MODSECURITY_VERSION:-3.0.12}"
MODSECURITY_NGINX_VERSION="${MODSECURITY_NGINX_VERSION:-1.0.3}"
SRC_DIR="/usr/local/src"
MODSECURITY_PREFIX="/usr/local/modsecurity"
INSTALL_PREFIX="${INSTALL_PREFIX:-/etc/nginx}"
MODSECURITY_CONFIG="${INSTALL_PREFIX}/modsecurity/modsec.conf"
MODSECURITY_LOG_DIR="/var/log/nginx/modsecurity"
CRS_DIR="/usr/share/modsecurity-crs"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm() {
    read -p "$1 [y/n]: " choice
    case "$choice" in
        y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

remove_modsecurity() {
    log_info "移除 ModSecurity..."
    if [ -d "${MODSECURITY_PREFIX}" ]; then
        rm -rf "${MODSECURITY_PREFIX}"
        log_info "ModSecurity 安装目录已删除"
    fi

    if [ -d "${SRC_DIR}/modsecurity-v${MODSECURITY_VERSION}" ]; then
        rm -rf "${SRC_DIR}/modsecurity-v${MODSECURITY_VERSION}"
        log_info "ModSecurity 源码已删除"
    fi

    if [ -d "${SRC_DIR}/modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}" ]; then
        rm -rf "${SRC_DIR}/modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}"
        log_info "ModSecurity-Nginx 连接器源码已删除"
    fi
}

remove_modsecurity_config() {
    log_info "移除 ModSecurity 配置..."
    if [ -d "${INSTALL_PREFIX}/modsecurity" ]; then
        rm -rf "${INSTALL_PREFIX}/modsecurity"
        log_info "ModSecurity 配置目录已删除"
    fi
}

remove_modsecurity_logs() {
    log_info "移除 ModSecurity 日志..."
    if [ -d "${MODSECURITY_LOG_DIR}" ]; then
        rm -rf "${MODSECURITY_LOG_DIR}"/*
        log_info "ModSecurity 日志已清除"
    fi
}

remove_crs_rules() {
    log_info "移除 CRS 规则集..."
    if [ -d "${CRS_DIR}" ]; then
        rm -rf "${CRS_DIR}"
        log_info "CRS 规则集已删除"
    fi
}

remove_modsecurity_lib_config() {
    log_info "移除 ModSecurity 库配置..."
    if [ -f "/etc/ld.so.conf.d/modsecurity.conf" ]; then
        rm -f "/etc/ld.so.conf.d/modsecurity.conf"
        ldconfig
        log_info "ModSecurity 库配置已删除"
    fi
}

remove_modsecurity_install_info() {
    log_info "移除 ModSecurity 安装信息..."
    if [ -f "/root/.modsecurity_install_info" ]; then
        rm -f "/root/.modsecurity_install_info"
        log_info "ModSecurity 安装信息已删除"
    fi
}

verify_removal() {
    log_info "验证清理结果..."
    local errors=0

    if [ -d "${MODSECURITY_PREFIX}" ]; then
        log_error "ModSecurity 目录仍然存在"
        ((errors++))
    fi

    if [ -d "${INSTALL_PREFIX}/modsecurity" ]; then
        log_error "ModSecurity 配置目录仍然存在"
        ((errors++))
    fi

    if [ -f "/etc/ld.so.conf.d/modsecurity.conf" ]; then
        log_error "ModSecurity 库配置仍然存在"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        log_info "ModSecurity 所有组件已成功卸载"
    else
        log_error "发现 $errors 个问题，请手动检查"
    fi
}

show_menu() {
    echo ""
    echo "=========================================="
    echo "  ModSecurity 深度卸载清理脚本"
    echo "=========================================="
    echo ""
    echo "1. 移除 ModSecurity 核心库"
    echo "2. 移除 ModSecurity 配置"
    echo "3. 移除 ModSecurity 日志"
    echo "4. 移除 CRS 规则集"
    echo "5. 移除 ModSecurity 库配置"
    echo "6. 移除 ModSecurity 安装信息"
    echo ""
    echo "a. 执行全部清理"
    echo "v. 验证清理结果"
    echo "q. 退出"
    echo ""
}

main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户运行此脚本"
        exit 1
    fi

    log_info "ModSecurity 深度卸载清理脚本"
    log_info "版本: ModSecurity ${MODSECURITY_VERSION}"
    echo ""

    if ! confirm "确定要执行 ModSecurity 卸载清理吗？此操作不可恢复"; then
        log_info "已取消"
        exit 0
    fi

    while true; do
        show_menu
        read -p "请选择操作: " choice

        case "$choice" in
            1) remove_modsecurity ;;
            2) remove_modsecurity_config ;;
            3) remove_modsecurity_logs ;;
            4) remove_crs_rules ;;
            5) remove_modsecurity_lib_config ;;
            6) remove_modsecurity_install_info ;;
            a|A)
                log_info "开始执行全部清理..."
                remove_modsecurity
                remove_modsecurity_config
                remove_modsecurity_logs
                remove_crs_rules
                remove_modsecurity_lib_config
                remove_modsecurity_install_info
                log_info "全部清理完成"
                ;;
            v|V) verify_removal ;;
            q|Q) exit 0 ;;
            *) log_error "无效选择" ;;
        esac
    done
}

main "$@"