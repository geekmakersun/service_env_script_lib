#!/bin/bash
#
# ModSecurity 3.0.12 源码编译安装脚本
# 用途: 从源码编译安装 ModSecurity v3
# 适配: Ubuntu 22.04.5 LTS
#

set -e # 遇到错误立即退出
set -u # 使用未定义变量时报错

# ========== 配置变量 ==========
# 可自定义的变量（可通过环境变量覆盖）
MODSECURITY_VERSION="${MODSECURITY_VERSION:-3.0.12}"
MODSECURITY_NGINX_VERSION="${MODSECURITY_NGINX_VERSION:-1.0.3}"
SRC_DIR="/usr/local/src"

# 日志文件
LOG_FILE="/var/log/modsecurity_install.log"
BACKUP_DIR="/service/nginx/backup"

# ========== 颜色定义 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ========== 进度条定义 ==========
TOTAL_STEPS=8
CURRENT_STEP=0

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local message="$3"

    local color
    if [[ $current -lt 3 ]]; then
        color="${RED}"
    elif [[ $current -lt 6 ]]; then
        color="${YELLOW}"
    else
        color="${GREEN}"
    fi

    printf "\r${CYAN}[进度]${NC} ${color}第${current}步/${total}步${NC} - ${CYAN}%s${NC}" "$message"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# 增加进度
next_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress "$CURRENT_STEP" "$TOTAL_STEPS" "$1"
}

# ========== 日志函数 ==========
log_info() {
    echo -e "${BLUE}[信息]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[错误]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# ========== 检查函数 ==========
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 用户运行此脚本"
        exit 1
    fi
}

check_system() {
    log_info "检查系统环境..."

    # 检查操作系统
    if ! grep -q "Ubuntu 22.04" /etc/os-release 2>/dev/null; then
        log_warn "未检测到 Ubuntu 22.04，脚本可能不兼容"
    fi

    log_success "系统检查完成"
}

# ========== 安装编译依赖 ==========
install_dependencies() {
    log_info "安装编译依赖..."

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq
    apt-get upgrade -y -qq

    # 安装编译工具和依赖库
    apt-get install -y -qq \
        build-essential \
        gcc \
        g++ \
        make \
        libtool \
        autoconf \
        automake \
        libpcre3 \
        libpcre3-dev \
        libssl-dev \
        zlib1g \
        zlib1g-dev \
        libxml2 \
        libxml2-dev \
        libxslt1-dev \
        libcurl4-openssl-dev \
        liblua5.3-dev \
        liblmdb-dev \
        libyaml-dev \
        libapr1-dev \
        libaprutil1-dev \
        libyajl-dev \
        libpcre2-dev \
        git \
        curl \
        wget \
        unzip \
        pkg-config \
        ca-certificates \
        flex \
        bison

    log_success "编译依赖安装完成"
}

# ========== 创建目录结构 ==========
setup_directories() {
    log_info "创建目录结构..."

    # 创建 ModSecurity 相关目录
    mkdir -p /etc/nginx/modsecurity/{rules,custom-rules,logs,tmp}
    mkdir -p /var/log/nginx/modsecurity
    mkdir -p ${SRC_DIR}

    # 创建 www-data 用户（如果不存在）
    if ! id -u www-data &>/dev/null; then
        groupadd -r www-data 2>/dev/null || true
        useradd -r -g www-data -s /bin/false -d /var/www -M www-data 2>/dev/null || true
    fi

    # 设置权限
    chown -R www-data:www-data /etc/nginx/modsecurity /var/log/nginx/modsecurity
    chmod -R 755 /etc/nginx/modsecurity
    chmod -R 700 /etc/nginx/modsecurity/tmp

    log_success "目录结构创建完成"
}

# ========== 下载源码 ==========
download_sources() {
    log_info "下载源码..."

    cd ${SRC_DIR}

    # 下载 ModSecurity v3
    if [[ ! -d "modsecurity-v${MODSECURITY_VERSION}/.git" ]]; then
        rm -rf "modsecurity-v${MODSECURITY_VERSION}"
        log_info "下载 ModSecurity ${MODSECURITY_VERSION}..."
        git clone --tags https://git.13aq.com/sunbingchen/ModSecurity-CN.git "modsecurity-v${MODSECURITY_VERSION}" || {
            log_error "ModSecurity 下载失败"
            exit 1
        }
    fi

    # 下载 ModSecurity-Nginx 连接器
    if [[ ! -d "modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}/.git" ]]; then
        rm -rf "modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}"
        log_info "下载 ModSecurity-Nginx 连接器 ${MODSECURITY_NGINX_VERSION}..."
        git clone https://git.13aq.com/sunbingchen/ModSecurity-nginx-cn.git "modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}" || {
            log_error "ModSecurity-Nginx 连接器下载失败"
            exit 1
        }
    fi

    log_success "源码下载完成"
}

# ========== 编译安装 ModSecurity ==========
compile_modsecurity() {
    log_info "编译安装 ModSecurity..."

    cd "${SRC_DIR}/modsecurity-v${MODSECURITY_VERSION}"

    # 清理之前的编译
    git submodule update --init --recursive 2>/dev/null || true

    # 配置编译
    ./build.sh
    ./configure \
        --prefix=/usr/local/modsecurity \
        --with-yajl \
        --with-lmdb \
        --with-lua \
        --with-curl \
        --with-pcre2 \
        --enable-parser-generation \
        --enable-mutex-on-pm

    # 编译安装
    make -j$(nproc)
    make install

    # 更新动态链接库缓存
    echo "/usr/local/modsecurity/lib" > /etc/ld.so.conf.d/modsecurity.conf
    ldconfig

    log_success "ModSecurity 编译安装完成"
}

# ========== 下载 CRS 规则 ==========
download_crs() {
    log_info "下载 OWASP CRS 规则集..."

    if [[ ! -d /usr/share/modsecurity-crs ]]; then
        cd /usr/share
        git clone --depth 1 https://git.13aq.com/sunbingchen/coreruleset-cn.git modsecurity-crs || {
            log_warn "CRS 规则集下载失败，将使用基础规则"
            mkdir -p /usr/share/modsecurity-crs/rules
        }
    fi

    # 创建 CRS 设置文件
    if [[ -f /usr/share/modsecurity-crs/crs-setup.conf.example ]]; then
        cp /usr/share/modsecurity-crs/crs-setup.conf.example /usr/share/modsecurity-crs/crs-setup.conf
    fi

    log_success "CRS 规则集下载完成"
}

# ========== 配置 ModSecurity ==========
configure_modsecurity() {
    log_info "配置 ModSecurity..."

    # 备份旧配置文件
    mkdir -p "${BACKUP_DIR}/modsecurity"
    for f in /etc/nginx/modsecurity/modsec.conf /etc/nginx/modsecurity/custom.conf; do
        if [[ -f "$f" ]]; then
            cp "$f" "${BACKUP_DIR}/modsecurity/$(basename "$f").bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        fi
    done

    # 创建 ModSecurity 主配置文件
    cat > /etc/nginx/modsecurity/modsec.conf << 'EOF'
# ModSecurity 核心配置
SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess On
SecResponseBodyMimeType text/plain text/html text/xml application/json

# 临时文件目录
SecDataDir /etc/nginx/modsecurity/tmp
SecTmpDir /etc/nginx/modsecurity/tmp

# 日志配置
SecDebugLog /var/log/nginx/modsecurity/debug.log
SecDebugLogLevel 0
SecAuditLog /var/log/nginx/modsecurity/audit.log
SecAuditLogFormat JSON
SecAuditLogType Serial
SecAuditEngine RelevantOnly
SecAuditLogRelevantStatus "^(?:5|4(?!04))"

# 请求限制
SecRequestBodyLimit 13107200
SecRequestBodyNoFilesLimit 131072
SecResponseBodyLimit 524288

# 文件上传
SecUploadDir /etc/nginx/modsecurity/tmp
SecUploadKeepFiles Off

# 加载 CRS 规则
Include /usr/share/modsecurity-crs/crs-setup.conf
Include /usr/share/modsecurity-crs/rules/*.conf

# 加载自定义规则
Include /etc/nginx/modsecurity/custom.conf
EOF

    # 创建自定义安全规则
    cat > /etc/nginx/modsecurity/custom.conf << 'EOF'
# ===========================================
# ModSecurity 自定义安全规则
# 规则 ID 范围: 100000-199999
# ===========================================

# ---------- XSS 攻击检测 (规则 ID: 100001-100099) ----------
SecRule REQUEST_URI|REQUEST_BODY|ARGS "@rx <script[\s\S]*?>|javascript:|on\w+\s*=" \
    "id:100001,phase:2,deny,status:403,log,msg:'检测到 XSS 攻击',setenv:MODSEC_ATTACK_TYPE=xss"

SecRule REQUEST_URI|REQUEST_BODY|ARGS "@rx <iframe|<object|<embed|<svg[\s\S]*?onload" \
    "id:100002,phase:2,deny,status:403,log,msg:'检测到 XSS 攻击 (iframe/object/embed)',setenv:MODSEC_ATTACK_TYPE=xss"

# ---------- SQL 注入检测 (规则 ID: 100100-100199) ----------
SecRule REQUEST_URI|REQUEST_BODY|ARGS "@rx (?i)(union\s+select|select\s+from|insert\s+into|delete\s+from|drop\s+table|update\s+\w+\s+set)" \
    "id:100100,phase:2,deny,status:403,log,msg:'检测到 SQL 注入攻击',setenv:MODSEC_ATTACK_TYPE=sql_injection"

SecRule REQUEST_URI|REQUEST_BODY|ARGS "@rx (?i)(or\s+1\s*=\s*1|and\s+1\s*=\s*1|'\s*or\s+'|\"\s*or\s+\")" \
    "id:100101,phase:2,deny,status:403,log,msg:'检测到 SQL 注入攻击 (布尔型)',setenv:MODSEC_ATTACK_TYPE=sql_injection"

# ---------- 命令注入检测 (规则 ID: 100200-100299) ----------
SecRule REQUEST_URI|REQUEST_BODY|ARGS "@rx (?i)(;|\||`|\$\(|\$\{)\s*(ls|cat|pwd|whoami|id|uname|wget|curl|nc|bash|sh|python|perl|ruby|php)" \
    "id:100200,phase:2,deny,status:403,log,msg:'检测到命令注入攻击',setenv:MODSEC_ATTACK_TYPE=command_injection"

# ---------- 文件包含攻击检测 (规则 ID: 100300-100399) ----------
SecRule REQUEST_URI|REQUEST_BODY|ARGS "@rx (?i)(php://|file://|expect://|data://|zip://|phar://)" \
    "id:100300,phase:2,deny,status:403,log,msg:'检测到文件包含攻击 (协议包装器)',setenv:MODSEC_ATTACK_TYPE=file_inclusion"

# ---------- 路径遍历攻击检测 (规则 ID: 100400-100499) ----------
SecRule REQUEST_URI|REQUEST_BODY|ARGS "@rx \.\./|\.\.\\" \
    "id:100400,phase:2,deny,status:403,log,msg:'检测到路径遍历攻击',setenv:MODSEC_ATTACK_TYPE=path_traversal"

# ---------- 敏感文件访问检测 (规则 ID: 100500-100599) ----------
SecRule REQUEST_URI "@rx (?i)\.(env|git|svn|bak|backup|sql|conf|config|ini|log|sh|py|pl|rb)$" \
    "id:100500,phase:2,deny,status:403,log,msg:'检测到敏感文件访问',setenv:MODSEC_ATTACK_TYPE=sensitive_file"

# ---------- 敏感路径访问检测 (规则 ID: 100600-100699) ----------
SecRule REQUEST_URI "@rx (?i)^/(admin|manager|phpmyadmin|mysql|backup|config|test|tmp|debug)" \
    "id:100600,phase:2,deny,status:403,log,msg:'检测到敏感路径访问',setenv:MODSEC_ATTACK_TYPE=sensitive_path"

# ---------- 恶意编码检测 (规则 ID: 100700-100799) ----------
SecRule REQUEST_URI|REQUEST_BODY|ARGS "@rx (?i)(%3Cscript|%3C/script|%3Ciframe|%3Cobject|%3Cembed|%253C)" \
    "id:100700,phase:2,deny,status:403,log,msg:'检测到恶意编码攻击',setenv:MODSEC_ATTACK_TYPE=malicious_encoding"
EOF

    # 配置文件权限
    chown -R www-data:www-data /etc/nginx/modsecurity
    chmod 640 /etc/nginx/modsecurity/modsec.conf
    chmod 640 /etc/nginx/modsecurity/custom.conf

    log_success "ModSecurity 配置完成"
}

# ========== 验证安装 ==========
verify_installation() {
    log_info "验证安装..."

    # 检查 ModSecurity 库
    if ldconfig -p | grep -q modsecurity; then
        log_success "ModSecurity 库已加载"
    else
        log_warn "ModSecurity 库可能未正确加载"
    fi

    # 检查 ModSecurity 配置文件
    if [[ -f /etc/nginx/modsecurity/modsec.conf ]]; then
        log_success "ModSecurity 配置文件已创建"
    else
        log_error "ModSecurity 配置文件未创建"
        exit 1
    fi

    log_success "安装验证完成"
}

# ========== 保存安装信息 ==========
save_install_info() {
    log_info "保存安装信息..."

    local INFO_FILE="/root/.modsecurity_install_info"
    cat > "${INFO_FILE}" << EOF
# ModSecurity 安装信息
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 版本信息
MODSECURITY_VERSION="${MODSECURITY_VERSION}"
MODSECURITY_NGINX_VERSION="${MODSECURITY_NGINX_VERSION}"

# 路径信息
MODSECURITY_PREFIX="/usr/local/modsecurity"
MODSECURITY_CONFIG="/etc/nginx/modsecurity/modsec.conf"
CUSTOM_RULES="/etc/nginx/modsecurity/custom.conf"

# 日志目录
MODSECURITY_LOG_DIR="/var/log/nginx/modsecurity"

# 注意事项
# 1. 若要在 Nginx 中启用 ModSecurity，需要重新编译 Nginx 并添加 ModSecurity 模块
# 2. 编译 Nginx 时使用 --add-module 参数添加 ModSecurity-Nginx 连接器
# 3. 在 Nginx 配置文件中添加以下指令启用 ModSecurity:
#    modsecurity on;
#    modsecurity_rules_file /etc/nginx/modsecurity/modsec.conf;
EOF

    chmod 600 "${INFO_FILE}"
    log_info "安装信息已保存到: ${INFO_FILE}"
}

# ========== 显示安装信息 ==========
show_summary() {
    echo ""
    echo "========================================"
    echo "    ModSecurity 安装完成"
    echo "========================================"
    echo ""
    echo "版本:"
    echo "  ModSecurity: ${MODSECURITY_VERSION}"
    echo "  ModSecurity-Nginx: ${MODSECURITY_NGINX_VERSION}"
    echo ""
    echo "配置文件:"
    echo "  ModSecurity: /etc/nginx/modsecurity/modsec.conf"
    echo "  自定义规则: /etc/nginx/modsecurity/custom.conf"
    echo ""
    echo "日志文件:"
    echo "  ModSecurity: /var/log/nginx/modsecurity/"
    echo "  安装日志: ${LOG_FILE}"
    echo ""
    echo "安装信息: /root/.modsecurity_install_info"
    echo ""
    echo "注意事项:"
    echo "  1. 若要在 Nginx 中启用 ModSecurity，需要重新编译 Nginx 并添加 ModSecurity 模块"
    echo "  2. 编译 Nginx 时使用 --add-module 参数添加 ModSecurity-Nginx 连接器"
    echo "  3. 在 Nginx 配置文件中添加以下指令启用 ModSecurity:"
    echo "     modsecurity on;"
    echo "     modsecurity_rules_file /etc/nginx/modsecurity/modsec.conf;"
    echo "========================================"
}

# ========== 清理函数 ==========
cleanup() {
    if [[ $? -ne 0 ]]; then
        log_error "安装过程中出现错误，请查看日志: ${LOG_FILE}"
        log_info "你可以从备份恢复配置: ${BACKUP_DIR}"
    fi
}

trap cleanup EXIT

# ========== 主函数 ==========
main() {
    echo "========================================"
    echo "  ModSecurity ${MODSECURITY_VERSION}"
    echo "  源码编译安装脚本"
    echo "========================================"
    echo ""

    # 初始化日志
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "# ModSecurity 安装日志" > "$LOG_FILE"
    echo "# 开始时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    check_root
    next_step "检查 root 权限"

    check_system
    next_step "检查系统环境"

    install_dependencies
    next_step "安装编译依赖"

    setup_directories
    next_step "创建目录结构"

    download_sources
    next_step "下载源码"

    compile_modsecurity
    next_step "编译安装 ModSecurity"

    download_crs
    next_step "下载 CRS 规则集"

    configure_modsecurity
    next_step "配置 ModSecurity"

    verify_installation
    next_step "验证安装"

    save_install_info

    show_summary

    log_success "ModSecurity 安装全部完成！"
}

# 如果直接运行脚本，执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi