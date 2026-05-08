#!/usr/bin/env bash
# ==============================================================
# setup-gns3-config.sh
# Creates ~/.config/GNS3/3.0/gns3_server.conf
#
# Why: Without this config:
#   - GNS3 runs with local=false (causes 405 on node start)
#   - JWT errors appear on every API call
#   - Node start fails with Method Not Allowed
#
# Usage: chmod +x setup-gns3-config.sh && ./setup-gns3-config.sh
# ==============================================================

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

CONFIG_DIR="$HOME/.config/GNS3/3.0"
CONFIG_FILE="$CONFIG_DIR/gns3_server.conf"

mkdir -p "$CONFIG_DIR"

# Generate cryptographically secure JWT key
SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
log_info "Generated JWT secret key (64 hex chars)"

# Detect binary paths
VPCS_PATH=$(which vpcs 2>/dev/null || echo "/usr/local/bin/vpcs")
DYNAMIPS_PATH=$(which dynamips 2>/dev/null || echo "/usr/bin/dynamips")
UBRIDGE_PATH=$(which ubridge 2>/dev/null || echo "/usr/local/bin/ubridge")

cat > "$CONFIG_FILE" << EOF
[Server]
host = 127.0.0.1
port = 3080
jwt_secret_key = ${SECRET}
local = true

[VPCS]
vpcs_path = ${VPCS_PATH}

[Dynamips]
dynamips_path = ${DYNAMIPS_PATH}

[QEMU]
enable_hardware_acceleration = true
require_hardware_acceleration = false
EOF

log_info "Config written to: $CONFIG_FILE"
echo ""
echo "Contents:"
cat "$CONFIG_FILE"
echo ""
log_warn "Keep the jwt_secret_key private — it signs all authentication tokens"
log_info "Now launch GNS3 with: gns3"
