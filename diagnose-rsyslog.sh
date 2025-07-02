#!/bin/bash

# =============================================================================
# DIAGNÓZA RSYSLOG PROBLÉMOV
# =============================================================================

set -e

echo "Diagnostikujem rsyslog problémy..."
echo "=================================="

# 1. Kontrola rsyslog status
echo "1. RSYSLOG STATUS:"
systemctl status rsyslog --no-pager
echo ""

# 2. Kontrola konfiguračného súboru
echo "2. KONFIGURAČNÝ SÚBOR:"
if [[ -f /etc/rsyslog.d/99-monitoring.conf ]]; then
    echo "✅ 99-monitoring.conf existuje:"
    cat /etc/rsyslog.d/99-monitoring.conf
else
    echo "❌ 99-monitoring.conf neexistuje"
fi
echo ""

# 3. Kontrola adresárov
echo "3. ADRESÁRE:"
echo "Adresár /opt/monitoring/:"
ls -la /opt/monitoring/
echo ""
echo "Adresár /opt/monitoring/logs/:"
ls -la /opt/monitoring/logs/
echo ""
echo "Adresár /opt/monitoring/kernel/:"
ls -la /opt/monitoring/kernel/
echo ""

# 4. Kontrola práv
echo "4. PRÁVA:"
echo "Vlastník /opt/monitoring/:"
stat -c "%U:%G" /opt/monitoring/
echo "Vlastník /opt/monitoring/logs/:"
stat -c "%U:%G" /opt/monitoring/logs/
echo ""

# 5. Kontrola log súborov
echo "5. LOG SÚBORY:"
echo "Log súbory v /opt/monitoring/logs/:"
ls -la /opt/monitoring/logs/*.log 2>/dev/null || echo "Žiadne log súbory"
echo ""
echo "Log súbory v /opt/monitoring/kernel/:"
ls -la /opt/monitoring/kernel/*.log 2>/dev/null || echo "Žiadne log súbory"
echo ""

# 6. Test rsyslog
echo "6. TEST RSYSLOG:"
echo "Posielam testovaciu správu..."
logger -t DIAGNOSE "Test message from diagnose script"
sleep 2

echo "Kontrolujem či sa správa zapísala:"
if [[ -f /opt/monitoring/logs/all.log ]]; then
    echo "✅ all.log existuje:"
    tail -3 /opt/monitoring/logs/all.log
else
    echo "❌ all.log neexistuje"
fi
echo ""

# 7. Kontrola rsyslog logov
echo "7. RSYSLOG LOGY:"
echo "Posledných 10 rsyslog správ:"
journalctl -u rsyslog -n 10 --no-pager
echo ""

# 8. Kontrola disk priestoru
echo "8. DISK PRIESTOR:"
df -h /opt/monitoring/
echo ""

echo "Diagnóza dokončená!" 