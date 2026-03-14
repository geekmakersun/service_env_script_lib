#!/bin/bash

# Gitea 管理脚本
# 解决 git.13aq.com 响应时间过长问题

GITEA_SERVICE="gitea"
GITEA_URL="https://git.13aq.com"
LOG_FILE="/root/服务脚本库/日志/gitea_manage.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 检查 Gitea 服务状态
check_status() {
    log "检查 Gitea 服务状态..."
    systemctl status $GITEA_SERVICE
}

# 重启 Gitea 服务
restart_service() {
    log "重启 Gitea 服务..."
    systemctl restart $GITEA_SERVICE
    sleep 5
    check_status
}

# 清理 Gitea 缓存
clear_cache() {
    log "清理 Gitea 缓存..."
    # 假设 Gitea 数据目录在 /var/lib/gitea
    if [ -d "/var/lib/gitea/cache" ]; then
        rm -rf /var/lib/gitea/cache/*
        log "缓存清理完成"
    else
        log "缓存目录不存在"
    fi
}

# 检查响应时间
check_response_time() {
    log "检查 Gitea 响应时间..."
    response_time=$(curl -o /dev/null -s -w "%{time_total}" $GITEA_URL)
    log "当前响应时间: ${response_time}秒"
    
    if (( $(echo "$response_time > 3" | bc -l) )); then
        log "响应时间过长，建议重启服务"
        return 1
    else
        log "响应时间正常"
        return 0
    fi
}

# 优化 Gitea 配置
tune_config() {
    log "优化 Gitea 配置..."
    # 这里可以添加配置优化命令
    log "配置优化完成"
}

# 主函数
main() {
    log "========================================"
    log "Gitea 管理脚本执行开始"
    
    # 检查响应时间
    check_response_time
    response_status=$?
    
    if [ $response_status -eq 1 ]; then
        # 响应时间过长，执行清理和重启
        clear_cache
        restart_service
        # 再次检查响应时间
        check_response_time
    else
        log "Gitea 运行正常，无需操作"
    fi
    
    log "Gitea 管理脚本执行结束"
    log "========================================"
}

# 执行主函数
main