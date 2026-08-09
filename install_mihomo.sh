#!/bin/bash

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

REQUIRED_CMDS=(curl gzip systemctl)
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        err "缺少必要命令: $cmd"
        exit 1
    fi
done

# ─── 目录定义 ──────────────────────────────────────────────
INSTALL_DIR="/usr/local/bin"
RUN_DIR="/opt/mihomo"
SERVICE_FILE="/etc/systemd/system/mihomo.service"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# ─── 1. 获取最新版本信息 ───────────────────────────────────
info "正在获取 mihomo 最新版本信息..."
GITHUB_API="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"

LATEST_JSON=$(curl -fsSL "$GITHUB_API") || {
    err "无法访问 GitHub API，请检查网络连接"
    exit 1
}

TAG_NAME=$(echo "$LATEST_JSON" | grep -oP '"tag_name":\s*"\K[^"]+') || {
    err "无法从 API 响应中解析 tag_name"
    exit 1
}

if [[ -z "$TAG_NAME" ]]; then
    err "获取到的 tag_name 为空"
    exit 1
fi

VERSION="${TAG_NAME#v}"                     # 去掉 "v" 前缀，如 v1.19.28 → 1.19.28
DOWNLOAD_TAG="$TAG_NAME"                     # URL 中使用带 v 的版本
FILENAME="mihomo-linux-amd64-v2-${TAG_NAME}.gz"
DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${DOWNLOAD_TAG}/${FILENAME}"

info "最新版本: ${GREEN}${TAG_NAME}${NC}"

# ─── 2. 下载并安装 ─────────────────────────────────────────
info "正在下载: ${DOWNLOAD_URL}"
curl -fsSL -o "${TMP_DIR}/${FILENAME}" "$DOWNLOAD_URL" || {
    err "下载失败: ${DOWNLOAD_URL}"
    exit 1
}
ok "下载完成"

info "解压..."
gzip -d "${TMP_DIR}/${FILENAME}" || {
    err "解压失败"
    exit 1
}

EXTRACTED_FILE="${TMP_DIR}/mihomo-linux-amd64-v2-${TAG_NAME}"
if [[ ! -f "$EXTRACTED_FILE" ]]; then
    EXTRACTED_FILE=$(find "$TMP_DIR" -type f ! -name '*.gz' 2>/dev/null | head -1)
fi

if [[ ! -f "$EXTRACTED_FILE" ]]; then
    err "解压后未找到二进制文件"
    exit 1
fi

if systemctl is-active --quiet mihomo 2>/dev/null; then
    info "停止 mihomo 服务..."
    systemctl stop mihomo
fi


info "安装二进制到 ${INSTALL_DIR}/mihomo"
install -m 755 "$EXTRACTED_FILE" "${INSTALL_DIR}/mihomo"
ok "二进制已安装"

# ─── 创建运行目录 ──────────────────────────────────────────
if [[ ! -d "$RUN_DIR" ]]; then
    info "创建运行目录: ${RUN_DIR}"
    mkdir -p "$RUN_DIR"
fi

# ─── 创建 systemd service ──────────────────────────────────
info "写入 systemd service 文件: ${SERVICE_FILE}"
cat > "$SERVICE_FILE" << 'SERVICEEOF'
[Unit]
Description=mihomo Daemon, Another Clash Kernel.
After=network.target NetworkManager.service systemd-networkd.service iwd.service

[Service]
Type=simple
LimitNPROC=500
LimitNOFILE=1000000
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
Restart=always
ExecStartPre=/usr/bin/sleep 1s
ExecStart=/usr/local/bin/mihomo -d /opt/mihomo
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
SERVICEEOF
ok "service 文件已写入"

# ─── 3. 创建配置文件 ───────────────────────────────────────
if [[ ! -f "${RUN_DIR}/config.yaml" ]]; then
    info "创建默认配置文件: ${RUN_DIR}/config.yaml"
    echo "mixed-port: 7890" > "${RUN_DIR}/config.yaml"
    ok "config.yaml 已创建"
else
    info "config.yaml 已存在，保留现有配置"
fi

# ─── 4. 清除旧资源 ─────────────────────────────────────────
# 清理临时下载目录（trap 自动处理）
info "清理临时文件..."

# 检查并清理旧版本备份（如果有）
OLD_BACKUP="${INSTALL_DIR}/mihomo.old"
if [[ -f "$OLD_BACKUP" ]]; then
    rm -f "$OLD_BACKUP"
    ok "已清除旧版本备份: ${OLD_BACKUP}"
fi

# ─── 重新加载 systemd 并启用服务 ───────────────────────────
info "重新加载 systemd 配置..."
systemctl daemon-reload

info "启用 mihomo 服务（开机自启）..."
systemctl enable mihomo

info "启动 mihomo 服务..."
systemctl start mihomo

# ─── 验证安装 ──────────────────────────────────────────────
sleep 1
if systemctl is-active --quiet mihomo; then
    ok "mihomo ${TAG_NAME} 安装完成并已成功启动！"
    echo ""
    echo -e "  版本:     ${GREEN}${TAG_NAME}${NC}"
    echo -e "  二进制:   ${INSTALL_DIR}/mihomo"
    echo -e "  运行目录: ${RUN_DIR}"
    echo -e "  配置:     ${RUN_DIR}/config.yaml"
    echo -e "  服务:     ${SERVICE_FILE}"
    echo ""
    echo "编辑配置后执行以下命令重载:"
    echo "  systemctl reload mihomo"
    echo ""
    echo "查看日志:"
    echo "  journalctl -u mihomo -f"
else
    warn "mihomo 服务未正常运行，请检查日志:"
    warn "  journalctl -u mihomo --no-pager -n 50"
    echo ""
    echo -e "二进制已安装至 ${INSTALL_DIR}/mihomo，可手动排查问题。"
fi
