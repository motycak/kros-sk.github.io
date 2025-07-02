#!/bin/bash

# =============================================================================
# SKRIPT PRE NASTAVENIE KOMPLETNÉHO LOGOVANIA NA LINUX MAŠINE
# Autor: AI Assistant
# Účel: Diagnostika problému s vytuhnutím mašiny
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

log "Začínam inštaláciu a konfiguráciu logovania..."

# =============================================================================
# 1. AKTUALIZÁCIA SYSTÉMU
# =============================================================================
log "Aktualizujem systém..."
apt update

# =============================================================================
# 2. INŠTALÁCIA POTREBNÝCH BALÍKOV
# =============================================================================
log "Inštalujem potrebné balíky..."

# Základné monitoring nástroje
apt install -y \
    htop \
    iotop \
    net-tools \
    bc \
    curl \
    wget \
    git

# Hardware monitoring
apt install -y \
    lm-sensors \
    smartmontools \
    powertop

# Logovanie a crash dump
apt install -y \
    kdump-tools \
    rsyslog \
    logrotate

# Systémové nástroje
apt install -y \
    sysstat \
    procps \
    util-linux

log "Všetky balíky boli úspešne nainštalované"

# =============================================================================
# 3. VYTVORENIE ADRESÁROV PRE LOGY
# =============================================================================
log "Vytváram adresárovú štruktúru pre logy..."

mkdir -p /opt/monitoring/logs
mkdir -p /opt/monitoring/hardware
mkdir -p /opt/monitoring/performance
mkdir -p /opt/monitoring/crashes
mkdir -p /opt/monitoring/kernel
mkdir -p /opt/monitoring/scripts

# Nastavenie práv
chmod 755 /opt/monitoring
chmod 755 /opt/monitoring/logs
chmod 755 /opt/monitoring/hardware
chmod 755 /opt/monitoring/performance
chmod 755 /opt/monitoring/crashes
chmod 755 /opt/monitoring/kernel
chmod 755 /opt/monitoring/scripts

# =============================================================================
# 4. KONFIGURÁCIA SENSORS
# =============================================================================
log "Konfigurujem hardware sensors..."
sensors-detect --auto

# =============================================================================
# 5. KONFIGURÁCIA KDUMP
# =============================================================================
log "Konfigurujem kernel crash dump..."

cat > /etc/default/kdump-tools << 'EOF'
USE_KDUMP=1
KDUMP_COREDIR="/opt/monitoring/crashes"
KDUMP_CMDLINE_APPEND="irqpoll maxcpus=1 reset_devices"
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

# =============================================================================
# 6. KONFIGURÁCIA RSYSLOG
# =============================================================================
log "Konfigurujem rsyslog..."

cat >> /etc/rsyslog.conf << 'EOF'

# =============================================================================
# CUSTOM LOGGING CONFIGURATION
# =============================================================================

# Logovanie všetkých správ do jedného súboru
*.* /opt/monitoring/logs/all.log

# Kernel správy
kern.* /opt/monitoring/kernel/kernel.log

# Kritické chyby
*.crit /opt/monitoring/logs/critical.log

# Chyby
*.err /opt/monitoring/logs/errors.log

# Varovania
*.warn /opt/monitoring/logs/warnings.log

# Docker správy
:programname, contains, "docker" /opt/monitoring/logs/docker.log

# Kubernetes správy
:programname, contains, "kube" /opt/monitoring/logs/kubernetes.log
:programname, contains, "k3s" /opt/monitoring/logs/kubernetes.log

# SSH správy
:programname, contains, "sshd" /opt/monitoring/logs/ssh.log
EOF

# =============================================================================
# 7. VYTVORENIE MONITORING SKRIPTU
# =============================================================================
log "Vytváram monitoring skript..."

cat > /opt/monitoring/scripts/system-monitor.sh << 'EOF'
#!/bin/bash

# =============================================================================
# SYSTEM MONITORING SCRIPT
# =============================================================================

LOG_DIR="/opt/monitoring/logs"
HARDWARE_LOG="/opt/monitoring/hardware/hardware.log"
PERFORMANCE_LOG="/opt/monitoring/performance/performance.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Vytvorenie adresárov ak neexistujú
mkdir -p "$LOG_DIR"
mkdir -p "/opt/monitoring/hardware"
mkdir -p "/opt/monitoring/performance"

# =============================================================================
# HARDWARE MONITORING
# =============================================================================
echo "=== HARDWARE MONITORING - $DATE ===" >> "$HARDWARE_LOG"

# CPU informácie
echo "CPU Usage: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1)%" >> "$HARDWARE_LOG"
echo "CPU Frequency: $(cat /proc/cpuinfo | grep 'cpu MHz' | head -1 | awk '{print $4}') MHz" >> "$HARDWARE_LOG"

# CPU Temperature - pokus o rôzne formáty senzorov
CPU_TEMP=$(sensors | grep -E '(Core|Tctl|temp1)' | head -1 | awk '{print $2}' | sed 's/[^0-9.]//g' 2>/dev/null)
if [[ -n "$CPU_TEMP" ]]; then
    echo "CPU Temperature: ${CPU_TEMP}°C" >> "$HARDWARE_LOG"
else
    echo "CPU Temperature: N/A" >> "$HARDWARE_LOG"
fi

# Memory informácie
echo "Memory Total: $(free -m | awk 'NR==2{print $2}') MB" >> "$HARDWARE_LOG"
echo "Memory Used: $(free -m | awk 'NR==2{print $3}') MB" >> "$HARDWARE_LOG"
echo "Memory Free: $(free -m | awk 'NR==2{print $4}') MB" >> "$HARDWARE_LOG"
echo "Memory Usage: $(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')" >> "$HARDWARE_LOG"

# Disk informácie
echo "Disk Usage: $(df -h / | awk 'NR==2{print $5}')" >> "$HARDWARE_LOG"
echo "Disk Available: $(df -h / | awk 'NR==2{print $4}')" >> "$HARDWARE_LOG"

# SMART informácie (ak je dostupné)
if command -v smartctl &> /dev/null; then
    echo "SMART Status: $(smartctl -H /dev/sda 2>/dev/null | grep 'SMART overall-health' | awk '{print $6}' || echo 'N/A')" >> "$HARDWARE_LOG"
fi

# Teplota (ak je dostupná)
if command -v sensors &> /dev/null; then
    echo "=== TEMPERATURE SENSORS ===" >> "$HARDWARE_LOG"
    sensors >> "$HARDWARE_LOG" 2>/dev/null || echo "Sensors not available" >> "$HARDWARE_LOG"
fi

# =============================================================================
# PERFORMANCE MONITORING
# =============================================================================
echo "=== PERFORMANCE MONITORING - $DATE ===" >> "$PERFORMANCE_LOG"

# Load average
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')" >> "$PERFORMANCE_LOG"

# Počet procesov
echo "Process Count: $(ps aux | wc -l)" >> "$PERFORMANCE_LOG"

# Sieťové spojenia
echo "Network Connections: $(netstat -an | wc -l)" >> "$PERFORMANCE_LOG"

# Docker kontajnery (ak je Docker dostupný)
if command -v docker &> /dev/null; then
    echo "Docker Containers: $(docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null | wc -l)" >> "$PERFORMANCE_LOG"
fi

# Kubernetes pods (ak je kubectl dostupný)
if command -v kubectl &> /dev/null; then
    echo "Kubernetes Pods: $(kubectl get pods --all-namespaces 2>/dev/null | wc -l)" >> "$PERFORMANCE_LOG"
fi

# I/O štatistiky
echo "=== I/O STATISTICS ===" >> "$PERFORMANCE_LOG"
iostat -x 1 1 >> "$PERFORMANCE_LOG" 2>/dev/null || echo "iostat not available" >> "$PERFORMANCE_LOG"

# Memory štatistiky
echo "=== MEMORY STATISTICS ===" >> "$PERFORMANCE_LOG"
vmstat >> "$PERFORMANCE_LOG" 2>/dev/null || echo "vmstat not available" >> "$PERFORMANCE_LOG"

echo "---" >> "$HARDWARE_LOG"
echo "---" >> "$PERFORMANCE_LOG"
EOF

chmod +x /opt/monitoring/scripts/system-monitor.sh

# =============================================================================
# 8. VYTVORENIE HEALTH CHECK SKRIPTU
# =============================================================================
log "Vytváram health check skript..."

cat > /opt/monitoring/scripts/health-check.sh << 'EOF'
#!/bin/bash

# =============================================================================
# HEALTH CHECK SCRIPT
# =============================================================================

LOG_FILE="/opt/monitoring/logs/health-check.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Kontrola či systém reaguje
if ! ping -c 1 127.0.0.1 &> /dev/null; then
    echo "$DATE: SYSTEM NEODPOVEDÁ - kritický problém!" >> "$LOG_FILE"
    # Tu môžete pridať automatický reštart alebo notifikáciu
fi

# Kontrola teploty
if command -v sensors &> /dev/null; then
    TEMP=$(sensors | grep -E '(Core|Tctl|temp1)' | head -1 | awk '{print $2}' | sed 's/[^0-9.]//g' 2>/dev/null)
    if [[ -n "$TEMP" && $(echo "$TEMP > 85" | bc -l 2>/dev/null) -eq 1 ]]; then
        echo "$DATE: VYSOKÁ TEPLOTA: ${TEMP}°C" >> "$LOG_FILE"
    fi
fi

# Kontrola dostupnej pamäte
MEM_USAGE=$(free -m | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [[ $MEM_USAGE -gt 90 ]]; then
    echo "$DATE: VYSOKÉ VYUŽITIE PAMÄTE: ${MEM_USAGE}%" >> "$LOG_FILE"
fi

# Kontrola disku
DISK_USAGE=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 90 ]]; then
    echo "$DATE: VYSOKÉ VYUŽITIE DISKU: ${DISK_USAGE}%" >> "$LOG_FILE"
fi

# Kontrola Docker (ak je dostupný)
if command -v docker &> /dev/null; then
    # Skontrolujte či je Docker daemon spustený
    if docker info &> /dev/null 2>&1; then
        # Test rôznych docker príkazov
        if ! docker ps &> /dev/null 2>&1 && ! docker version &> /dev/null 2>&1 && ! docker system info &> /dev/null 2>&1; then
            echo "$DATE: DOCKER NEODPOVEDÁ" >> "$LOG_FILE"
        fi
    else
        # Docker nie je spustený
        # Nezapisujeme chybu, pretože to nie je problém
        :
    fi
fi

# Kontrola Kubernetes (ak je dostupný)
if command -v kubectl &> /dev/null; then
    # Skontrolujte či je Kubernetes cluster dostupný
    if kubectl cluster-info &> /dev/null 2>&1; then
        # Test rôznych kubectl príkazov
        if ! kubectl get nodes &> /dev/null 2>&1 && ! kubectl get pods --all-namespaces &> /dev/null 2>&1 && ! kubectl version --client &> /dev/null 2>&1; then
            echo "$DATE: KUBERNETES NEODPOVEDÁ" >> "$LOG_FILE"
        fi
    else
        # Kubernetes nie je spustený alebo nie je nakonfigurovaný
        # Nezapisujeme chybu, pretože to nie je problém
        :
    fi
fi
EOF

chmod +x /opt/monitoring/scripts/health-check.sh

# =============================================================================
# 9. KONFIGURÁCIA CRON JOBOV
# =============================================================================
log "Nastavujem cron joby..."

# Vytvorenie crontab súboru
cat > /tmp/monitoring-cron << 'EOF'
# System monitoring každé 2 minúty
*/2 * * * * /opt/monitoring/scripts/system-monitor.sh

# Health check každú minútu
* * * * * /opt/monitoring/scripts/health-check.sh

# Denné zálohovanie logov
0 2 * * * find /opt/monitoring -name "*.log" -mtime +7 -exec gzip {} \;

# Týždenné čistenie starých logov
0 3 * * 0 find /opt/monitoring -name "*.log.gz" -mtime +30 -delete
EOF

# Pridanie do root crontab
crontab /tmp/monitoring-cron
rm /tmp/monitoring-cron

# =============================================================================
# 10. KONFIGURÁCIA LOGROTATE
# =============================================================================
log "Konfigurujem logrotate..."

cat > /etc/logrotate.d/monitoring << 'EOF'
/opt/monitoring/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/opt/monitoring/hardware/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}

/opt/monitoring/performance/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}

/opt/monitoring/kernel/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# =============================================================================
# 11. VYTVORENIE ANALÝZNEHO SKRIPTU
# =============================================================================
log "Vytváram analytický skript..."

cat > /opt/monitoring/scripts/analyze-logs.sh << 'EOF'
#!/bin/bash

# =============================================================================
# LOG ANALYSIS SCRIPT
# =============================================================================

LOG_DIR="/opt/monitoring/logs"
HARDWARE_LOG="/opt/monitoring/hardware/hardware.log"
PERFORMANCE_LOG="/opt/monitoring/performance/performance.log"
ANALYSIS_FILE="/opt/monitoring/logs/analysis-$(date +%Y%m%d-%H%M%S).txt"

echo "=== ANALÝZA LOGOV - $(date) ===" > "$ANALYSIS_FILE"
echo "" >> "$ANALYSIS_FILE"

# Analýza kritických chýb
echo "=== KRITICKÉ CHYBY ===" >> "$ANALYSIS_FILE"
if [[ -f "$LOG_DIR/critical.log" ]]; then
    tail -50 "$LOG_DIR/critical.log" >> "$ANALYSIS_FILE"
else
    echo "Žiadne kritické chyby" >> "$ANALYSIS_FILE"
fi
echo "" >> "$ANALYSIS_FILE"

# Analýza chýb
echo "=== CHYBY ===" >> "$ANALYSIS_FILE"
if [[ -f "$LOG_DIR/errors.log" ]]; then
    tail -50 "$LOG_DIR/errors.log" >> "$ANALYSIS_FILE"
else
    echo "Žiadne chyby" >> "$ANALYSIS_FILE"
fi
echo "" >> "$ANALYSIS_FILE"

# Analýza varovaní
echo "=== VAROVANIA ===" >> "$ANALYSIS_FILE"
if [[ -f "$LOG_DIR/warnings.log" ]]; then
    tail -50 "$LOG_DIR/warnings.log" >> "$ANALYSIS_FILE"
else
    echo "Žiadne varovania" >> "$ANALYSIS_FILE"
fi
echo "" >> "$ANALYSIS_FILE"

# Analýza hardware logov
echo "=== HARDWARE ANALÝZA ===" >> "$ANALYSIS_FILE"
if [[ -f "$HARDWARE_LOG" ]]; then
    echo "Posledných 20 záznamov:" >> "$ANALYSIS_FILE"
    tail -20 "$HARDWARE_LOG" >> "$ANALYSIS_FILE"
else
    echo "Hardware log neexistuje" >> "$ANALYSIS_FILE"
fi
echo "" >> "$ANALYSIS_FILE"

# Analýza performance logov
echo "=== PERFORMANCE ANALÝZA ===" >> "$ANALYSIS_FILE"
if [[ -f "$PERFORMANCE_LOG" ]]; then
    echo "Posledných 20 záznamov:" >> "$ANALYSIS_FILE"
    tail -20 "$PERFORMANCE_LOG" >> "$ANALYSIS_FILE"
else
    echo "Performance log neexistuje" >> "$ANALYSIS_FILE"
fi
echo "" >> "$ANALYSIS_FILE"

# Analýza health check logov
echo "=== HEALTH CHECK ANALÝZA ===" >> "$ANALYSIS_FILE"
if [[ -f "$LOG_DIR/health-check.log" ]]; then
    echo "Posledných 20 záznamov:" >> "$ANALYSIS_FILE"
    tail -20 "$LOG_DIR/health-check.log" >> "$ANALYSIS_FILE"
else
    echo "Health check log neexistuje" >> "$ANALYSIS_FILE"
fi

echo "Analýza dokončená: $ANALYSIS_FILE"
EOF

chmod +x /opt/monitoring/scripts/analyze-logs.sh

# =============================================================================
# 12. RESTART SLUŽIEB
# =============================================================================
log "Reštartujem služby..."

systemctl restart rsyslog
systemctl enable kdump-tools
systemctl start kdump-tools

# =============================================================================
# 13. VYTVORENIE README SÚBORU
# =============================================================================
log "Vytváram dokumentáciu..."

cat > /opt/monitoring/README.md << 'EOF'
# SYSTÉMOVÉ LOGOVANIE - DOKUMENTÁCIA

## Prečo toto logovanie?

Tento systém bol nastavený pre diagnostiku problému s vytuhnutím mašiny.
Keďže sa problém opakuje na rôznych OS (Windows aj Linux), je to pravdepodobne
hardvérový problém.

## Čo sa loguje?

### 1. Hardware monitoring
- CPU využitie a teplota
- Pamäť (RAM) využitie
- Disk využitie a SMART stav
- Teplota všetkých senzorov

### 2. Performance monitoring
- Load average
- Počet procesov
- Sieťové spojenia
- I/O štatistiky
- Docker a Kubernetes stav

### 3. Systémové logy
- Všetky kernel správy
- Kritické chyby
- Varovania
- Docker a Kubernetes správy

### 4. Health checks
- Kontrola dostupnosti služieb
- Kontrola teploty
- Kontrola využitia zdrojov

## Kde nájdete logy?

- `/opt/monitoring/logs/` - hlavné logy
- `/opt/monitoring/hardware/` - hardware monitoring
- `/opt/monitoring/performance/` - performance monitoring
- `/opt/monitoring/kernel/` - kernel správy
- `/opt/monitoring/crashes/` - kernel crash dumps
- `/opt/monitoring/scripts/` - skripty

## Ako analyzovať logy?

### Po vytuhnutí mašiny:

1. **Najprv spustite analýzu:**
   ```bash
   sudo /opt/monitoring/scripts/analyze-logs.sh
   ```

2. **Skontrolujte kritické chyby:**
   ```bash
   sudo tail -100 /opt/monitoring/logs/critical.log
   ```

3. **Skontrolujte hardware logy:**
   ```bash
   sudo tail -50 /opt/monitoring/hardware/hardware.log
   ```

4. **Skontrolujte kernel logy:**
   ```bash
   sudo dmesg | tail -50
   sudo journalctl -k | tail -50
   ```

5. **Skontrolujte crash dumps:**
   ```bash
   sudo ls -la /opt/monitoring/crashes/
   ```

## Cron joby

- System monitoring: každé 2 minúty
- Health check: každú minútu
- Log rotation: denne
- Log cleanup: týždenne

## Užitočné príkazy

```bash
# Sledovanie logov v reálnom čase
sudo tail -f /opt/monitoring/logs/all.log

# Kontrola teploty
sudo sensors

# Kontrola pamäte
sudo free -h

# Kontrola disku
sudo df -h

# Kontrola procesov
sudo htop

# Kontrola I/O
sudo iotop
```

## Čo hľadať pri analýze?

1. **Vysoká teplota** - nad 85°C
2. **Vysoké využitie pamäte** - nad 90%
3. **Vysoké využitie disku** - nad 90%
4. **Kernel panics** - v dmesg alebo crash dumps
5. **Hardware chyby** - v kernel logoch
6. **Nestabilné napájanie** - v SMART logoch

## Kontakt

Pri problémoch kontaktujte systémového administrátora.
EOF

# =============================================================================
# 14. FINÁLNE TESTOVANIE
# =============================================================================
log "Testujem nastavenia..."

# Test sensors
if command -v sensors &> /dev/null; then
    log "Sensors: OK"
else
    warning "Sensors nie je dostupné"
fi

# Test monitoring skriptu
if /opt/monitoring/scripts/system-monitor.sh; then
    log "System monitor: OK"
else
    error "System monitor zlyhal"
fi

# Test health check skriptu
if /opt/monitoring/scripts/health-check.sh; then
    log "Health check: OK"
else
    error "Health check zlyhal"
fi

# =============================================================================
# 15. ZÁVEREČNÉ INFORMÁCIE
# =============================================================================
log "Inštalácia dokončená úspešne!"

echo ""
echo "=================================================================="
echo "                    NASTAVENIE DOKONČENÉ"
echo "=================================================================="
echo ""
echo "📁 Logy sa nachádzajú v:"
echo "   - /opt/monitoring/logs/"
echo "   - /opt/monitoring/hardware/"
echo "   - /opt/monitoring/performance/"
echo "   - /opt/monitoring/kernel/"
echo ""
echo "🔧 Skripty sa nachádzajú v:"
echo "   - /opt/monitoring/scripts/"
echo ""
echo "📊 Pre analýzu logov použite:"
echo "   sudo /opt/monitoring/scripts/analyze-logs.sh"
echo ""
echo "📖 Dokumentácia:"
echo "   /opt/monitoring/README.md"
echo ""
echo "⏰ Monitoring beží automaticky každé 2 minúty"
echo "🏥 Health check beží každú minútu"
echo ""
echo "=================================================================="
echo ""

# Zobrazenie aktuálneho stavu
log "Aktuálny stav systému:"
echo "CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory: $(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')"
echo "Disk: $(df -h / | awk 'NR==2{print $5}')"

if command -v sensors &> /dev/null; then
    TEMP=$(sensors | grep -E '(Core|Tctl|temp1)' | head -1 | awk '{print $2}' | sed 's/[^0-9.]//g' 2>/dev/null)
    if [[ -n "$TEMP" ]]; then
        echo "Temperature: ${TEMP}°C"
    else
        echo "Temperature: N/A"
    fi
fi

log "Inštalácia je dokončená. Logy sa budú automaticky zbierať." 