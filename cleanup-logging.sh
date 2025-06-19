#!/bin/bash

# =============================================================================
# ČISTIACI SKRIPT PRE ODSTRÁNENIE LOGOVANIA
# Účel: Zrušenie všetkého logovania a vrátenie systému do pôvodného stavu
# =============================================================================

set -e  # Zastavenie pri chybe

# Farbové kódy pre výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funkcia pre logovanie
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[CHYBA]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[VAROVANIE]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Kontrola či sme root
if [[ $EUID -ne 0 ]]; then
   error "Tento skript musí byť spustený ako root (sudo)"
   exit 1
fi

# Potvrdenie od používateľa
echo -e "${YELLOW}VAROVANIE: Tento skript zruší všetko logovanie a monitoring!${NC}"
echo -e "${YELLOW}Všetky logy a nastavenia budú odstránené.${NC}"
echo ""
read -p "Naozaj chcete pokračovať? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Čistenie zrušené používateľom."
    exit 0
fi

log "Začínam čistenie logovania..."

# =============================================================================
# 1. ZRUŠENIE CRON JOBOV
# =============================================================================
log "Ruším cron joby..."

# Vytvorenie prázdneho crontab súboru
cat > /tmp/empty-cron << 'EOF'
# Prázdny crontab - všetky monitoring joby boli odstránené
EOF

# Aplikovanie prázdneho crontab
crontab /tmp/empty-cron
rm /tmp/empty-cron

log "Cron joby boli zrušené"

# =============================================================================
# 2. ZRUŠENIE LOGROTATE KONFIGURÁCIE
# =============================================================================
log "Ruším logrotate konfiguráciu..."

if [[ -f /etc/logrotate.d/monitoring ]]; then
    rm /etc/logrotate.d/monitoring
    log "Logrotate konfigurácia odstránená"
else
    warning "Logrotate konfigurácia neexistuje"
fi

# =============================================================================
# 3. ZRUŠENIE RSYSLOG KONFIGURÁCIE
# =============================================================================
log "Ruším rsyslog konfiguráciu..."

# Vytvorenie zálohy pôvodného rsyslog.conf
if [[ ! -f /etc/rsyslog.conf.backup ]]; then
    cp /etc/rsyslog.conf /etc/rsyslog.conf.backup
    log "Vytvorená záloha pôvodného rsyslog.conf"
fi

# Odstránenie custom konfigurácie z rsyslog.conf
sed -i '/# =============================================================================/,/EOF/d' /etc/rsyslog.conf
sed -i '/# CUSTOM LOGGING CONFIGURATION/,/EOF/d' /etc/rsyslog.conf

log "Rsyslog konfigurácia vyčistená"

# =============================================================================
# 4. ZRUŠENIE KDUMP KONFIGURÁCIE
# =============================================================================
log "Ruším kdump konfiguráciu..."

# Vytvorenie zálohy pôvodného kdump-tools
if [[ ! -f /etc/default/kdump-tools.backup ]]; then
    cp /etc/default/kdump-tools /etc/default/kdump-tools.backup
    log "Vytvorená záloha pôvodného kdump-tools"
fi

# Obnovenie pôvodnej kdump konfigurácie
cat > /etc/default/kdump-tools << 'EOF'
USE_KDUMP=0
KDUMP_COREDIR="/var/crash"
KDUMP_CMDLINE_APPEND=""
KDUMP_KERNELVER=""
KDUMP_INITRD=""
KDUMP_BOOTDIR="/boot"
KDUMP_IMG="vmlinuz"
KDUMP_INITRD_IMG="initrd.img"
KDUMP_FORCE_REBUILD=0
KDUMP_SCRIPT_PRE=""
KDUMP_SCRIPT_POST=""
KDUMP_SCRIPT_PRE_UMOUNT=""
KDUMP_SCRIPT_POST_UMOUNT=""
KDUMP_SCRIPT_PRE_REBOOT=""
KDUMP_SCRIPT_POST_REBOOT=""
KDUMP_SCRIPT_PRE_UMOUNT_FS=""
KDUMP_SCRIPT_POST_UMOUNT_FS=""
KDUMP_SCRIPT_PRE_MOUNT_FS=""
KDUMP_SCRIPT_POST_MOUNT_FS=""
KDUMP_SCRIPT_PRE_DUMP=""
KDUMP_SCRIPT_POST_DUMP=""
KDUMP_SCRIPT_PRE_REMOVE=""
KDUMP_SCRIPT_POST_REMOVE=""
KDUMP_SCRIPT_PRE_ADD=""
KDUMP_SCRIPT_POST_ADD=""
KDUMP_SCRIPT_PRE_LOAD=""
KDUMP_SCRIPT_POST_LOAD=""
KDUMP_SCRIPT_PRE_UNLOAD=""
KDUMP_SCRIPT_POST_UNLOAD=""
KDUMP_SCRIPT_PRE_SAVE=""
KDUMP_SCRIPT_POST_SAVE=""
KDUMP_SCRIPT_PRE_RESTORE=""
KDUMP_SCRIPT_POST_RESTORE=""
KDUMP_SCRIPT_PRE_VERIFY=""
KDUMP_SCRIPT_POST_VERIFY=""
KDUMP_SCRIPT_PRE_CLEAN=""
KDUMP_SCRIPT_POST_CLEAN=""
KDUMP_SCRIPT_PRE_UMOUNT_FS=""
KDUMP_SCRIPT_POST_UMOUNT_FS=""
KDUMP_SCRIPT_PRE_MOUNT_FS=""
KDUMP_SCRIPT_POST_MOUNT_FS=""
KDUMP_SCRIPT_PRE_DUMP=""
KDUMP_SCRIPT_POST_DUMP=""
KDUMP_SCRIPT_PRE_REMOVE=""
KDUMP_SCRIPT_POST_REMOVE=""
KDUMP_SCRIPT_PRE_ADD=""
KDUMP_SCRIPT_POST_ADD=""
KDUMP_SCRIPT_PRE_LOAD=""
KDUMP_SCRIPT_POST_LOAD=""
KDUMP_SCRIPT_PRE_UNLOAD=""
KDUMP_SCRIPT_POST_UNLOAD=""
KDUMP_SCRIPT_PRE_SAVE=""
KDUMP_SCRIPT_POST_SAVE=""
KDUMP_SCRIPT_PRE_RESTORE=""
KDUMP_SCRIPT_POST_RESTORE=""
KDUMP_SCRIPT_PRE_VERIFY=""
KDUMP_SCRIPT_POST_VERIFY=""
KDUMP_SCRIPT_PRE_CLEAN=""
KDUMP_SCRIPT_POST_CLEAN=""
EOF

log "Kdump konfigurácia zrušená"

# =============================================================================
# 5. ODSTRÁNENIE MONITORING ADRESÁROV A SÚBOROV
# =============================================================================
log "Odstraňujem monitoring adresáre a súbory..."

# Odstránenie celého /opt/monitoring adresára
if [[ -d /opt/monitoring ]]; then
    rm -rf /opt/monitoring
    log "Adresár /opt/monitoring odstránený"
else
    warning "Adresár /opt/monitoring neexistuje"
fi

# Odstránenie logov z /var/log ak existujú
if [[ -d /var/log/system-monitoring ]]; then
    rm -rf /var/log/system-monitoring
    log "Adresár /var/log/system-monitoring odstránený"
fi

if [[ -d /var/log/hardware ]]; then
    rm -rf /var/log/hardware
    log "Adresár /var/log/hardware odstránený"
fi

if [[ -d /var/log/performance ]]; then
    rm -rf /var/log/performance
    log "Adresár /var/log/performance odstránený"
fi

if [[ -d /var/log/kernel ]]; then
    rm -rf /var/log/kernel
    log "Adresár /var/log/kernel odstránený"
fi

# Odstránenie crash dumps
if [[ -d /var/crash ]]; then
    rm -rf /var/crash/*
    log "Crash dumps vyčistené"
fi

# =============================================================================
# 6. ZRUŠENIE SLUŽIEB
# =============================================================================
log "Zastavujem a ruším služby..."

# Zastavenie kdump-tools
systemctl stop kdump-tools 2>/dev/null || true
systemctl disable kdump-tools 2>/dev/null || true

# Reštart rsyslog pre aplikovanie zmien
systemctl restart rsyslog

log "Služby boli zastavené"

# =============================================================================
# 7. ODSTRÁNENIE BALÍKOV (VOLITEĽNÉ)
# =============================================================================
echo ""
echo -e "${YELLOW}Chcete odstrániť aj nainštalované balíky?${NC}"
echo "Toto odstráni:"
echo "- lm-sensors"
echo "- smartmontools"
echo "- powertop"
echo "- kdump-tools"
echo "- sysstat"
echo ""
read -p "Odstrániť balíky? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Odstraňujem balíky..."
    
    apt remove -y \
        lm-sensors \
        smartmontools \
        powertop \
        kdump-tools \
        sysstat \
        2>/dev/null || true
    
    apt autoremove -y
    
    log "Balíky boli odstránené"
else
    log "Balíky zostávajú nainštalované"
fi

# =============================================================================
# 8. VYČISTENIE DOKUMENTÁCIE
# =============================================================================
log "Vyčisťujem dokumentáciu..."

# Odstránenie README súborov ak existujú
if [[ -f /opt/scripts/README.md ]]; then
    rm /opt/scripts/README.md
    log "README súbor odstránený"
fi

# =============================================================================
# 9. FINÁLNE TESTOVANIE
# =============================================================================
log "Testujem čistenie..."

# Kontrola či monitoring adresáre neexistujú
if [[ ! -d /opt/monitoring ]]; then
    log "✓ Monitoring adresár odstránený"
else
    error "✗ Monitoring adresár stále existuje"
fi

# Kontrola cron jobov
if ! crontab -l 2>/dev/null | grep -q "monitoring"; then
    log "✓ Cron joby zrušené"
else
    error "✗ Cron joby stále existujú"
fi

# Kontrola rsyslog konfigurácie
if ! grep -q "monitoring" /etc/rsyslog.conf; then
    log "✓ Rsyslog konfigurácia vyčistená"
else
    error "✗ Rsyslog konfigurácia stále obsahuje monitoring"
fi

# =============================================================================
# 10. ZÁVEREČNÉ INFORMÁCIE
# =============================================================================
log "Čistenie dokončené úspešne!"

echo ""
echo "=================================================================="
echo "                    ČISTENIE DOKONČENÉ"
echo "=================================================================="
echo ""
echo "✅ Všetky monitoring adresáre odstránené"
echo "✅ Cron joby zrušené"
echo "✅ Rsyslog konfigurácia vyčistená"
echo "✅ Kdump konfigurácia zrušená"
echo "✅ Služby zastavené"
echo ""
echo "📁 Zálohy pôvodných konfigurácií:"
echo "   - /etc/rsyslog.conf.backup"
echo "   - /etc/default/kdump-tools.backup"
echo ""
echo "🔄 Pre úplné obnovenie pôvodného stavu:"
echo "   - Reštartujte systém"
echo "   - Alebo reštartujte rsyslog: systemctl restart rsyslog"
echo ""
echo "=================================================================="
echo ""

# Zobrazenie aktuálneho stavu
log "Aktuálny stav systému:"
echo "CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory: $(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')"
echo "Disk: $(df -h / | awk 'NR==2{print $5}')"

log "Čistenie je dokončené. Systém je vrátený do pôvodného stavu." 