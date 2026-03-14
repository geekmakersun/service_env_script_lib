#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PHP_VERSION="${PHP_VERSION:-8.4}"
INSTALL_PREFIX="/usr/local/php84"
SRC_DIR="/service/php"
LOG_DIR="/var/log/php-fpm"
RUN_DIR="/var/run/php-fpm"
TMP_DIR="/usr/local/php84/tmp"
SYSTEMD_UNIT_DIR="/etc/systemd/system"
INFO_FILE="/root/.php_install_info"

log_info() {
    echo -e "${BLUE}[信息]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 用户运行此脚本"
        exit 1
    fi
}

stop_php_fpm() {
    log_info "停止 PHP-FPM 服务..."
    if systemctl is-active --quiet php84-fpm 2>/dev/null; then
        systemctl stop php84-fpm
        log_info "PHP-FPM 已停止"
    fi
    if systemctl is-enabled --quiet php84-fpm 2>/dev/null; then
        systemctl disable php84-fpm
        log_info "PHP-FPM 已禁用开机自启"
    fi
}

remove_systemd_service() {
    log_info "移除 PHP-FPM systemd 服务..."
    if [ -f "${SYSTEMD_UNIT_DIR}/php84-fpm.service" ]; then
        rm -f "${SYSTEMD_UNIT_DIR}/php84-fpm.service"
        systemctl daemon-reload
        log_info "PHP-FPM 服务文件已删除"
    fi
}

remove_php_binary() {
    log_info "移除 PHP 二进制文件..."
    if [ -f "/usr/local/php84/bin/php" ]; then
        rm -rf /usr/local/php84
        log_info "PHP 安装目录已删除"
    fi
}

remove_php_directories() {
    log_info "清理 PHP 相关目录..."
    
    if [ -d "${LOG_DIR}" ]; then
        rm -rf "${LOG_DIR}"
        log_info "日志目录已删除"
    fi
    
    if [ -d "${RUN_DIR}" ]; then
        rm -rf "${RUN_DIR}"
        log_info "运行目录已删除"
    fi
    
    if [ -d "${SRC_DIR}" ]; then
        rm -rf "${SRC_DIR}"
        log_info "源码目录已删除"
    fi
    
    if [ -f "/etc/tmpfiles.d/php-fpm.conf" ]; then
        rm -f /etc/tmpfiles.d/php-fpm.conf
        log_info "tmpfiles.d 配置已删除"
    fi
    
    if [ -d "/var/www" ]; then
        rm -rf /var/www
        log_info "www 目录已删除"
    fi
}

remove_php_user() {
    log_info "清理 PHP 用户..."
    if id -u www-data &>/dev/null; then
        userdel www-data 2>/dev/null || true
        groupdel www-data 2>/dev/null || true
        log_info "www-data 用户已删除"
    fi
}

remove_pear_pecl() {
    log_info "清理 PECL 扩展..."
    if [ -d "/usr/local/php84/lib/php" ]; then
        rm -rf /usr/local/php84/lib/php
        log_info "PECL 扩展目录已删除"
    fi
}

remove_info_file() {
    log_info "清理安装信息文件..."
    if [ -f "${INFO_FILE}" ]; then
        rm -f "${INFO_FILE}"
        log_info "安装信息文件已删除"
    fi
}

cleanup_path() {
    log_info "检查 PATH 环境变量..."
    if grep -q "/usr/local/php84/bin" /etc/profile 2>/dev/null; then
        sed -i '/\/usr\/local\/php84\/bin/d' /etc/profile
        log_info "PATH 配置已清理"
    fi
    if grep -q "/usr/local/php84/bin" /root/.bashrc 2>/dev/null; then
        sed -i '/\/usr\/local\/php84\/bin/d' /root/.bashrc
        log_info "bashrc 配置已清理"
    fi
}

main() {
    echo "========================================"
    echo "  PHP ${PHP_VERSION} 卸载清理脚本"
    echo "========================================"
    echo ""
    
    check_root
    
    log_info "开始卸载 PHP ${PHP_VERSION}..."
    
    stop_php_fpm
    remove_systemd_service
    remove_php_binary
    remove_php_directories
    remove_php_user
    remove_pear_pecl
    remove_info_file
    cleanup_path
    
    log_success "PHP ${PHP_VERSION} 卸载清理完成！"
    log_info "注意: 如果之前有站点使用 PHP，请重新配置 Nginx"
}

main "$@"
