#!/bin/bash

# =============================================================================
# VYČISTENIE DUPLICITNEJ RSYSLOG KONFIGURÁCIE
# =============================================================================

set -e

echo "Vyčistím duplicitnú rsyslog konfiguráciu..."

# 1. Zálohujte pôvodný súbor
echo "Zálohujem pôvodný rsyslog.conf..."
sudo cp /etc/rsyslog.conf /etc/rsyslog.conf.backup

# 2. Vytvorte čistý rsyslog.conf
echo "Vytváram čistý rsyslog.conf..."
sudo tee /etc/rsyslog.conf > /dev/null << 'EOF'
# /etc/rsyslog.conf configuration file for rsyslog
#
# For more information install rsyslog-doc and see
# /usr/share/doc/rsyslog-doc/html/configuration/index.html
#
# Default logging rules can be found in /etc/rsyslog.d/50-default.conf


#################
#### MODULES ####
#################

module(load="imuxsock") # provides support for local system logging
#module(load="immark")  # provides --MARK-- message capability

# provides UDP syslog reception
#module(load="imudp")
#input(type="imudp" port="514")

# provides TCP syslog reception
#module(load="imtcp")
#input(type="imtcp" port="514")

# provides kernel logging support and enable non-kernel klog messages
module(load="imklog" permitnonkernelfacility="on")

###########################
#### GLOBAL DIRECTIVES ####
###########################

# Filter duplicated messages
$RepeatedMsgReduction on

#
# Set the default permissions for all log files.
#
$FileOwner syslog
$FileGroup adm
$FileCreateMode 0640
$DirCreateMode 0755
$Umask 0022
$PrivDropToUser syslog
$PrivDropToGroup syslog

#
# Where to place spool and state files
#
$WorkDirectory /var/spool/rsyslog

#
# Include all config files in /etc/rsyslog.d/
#
$IncludeConfig /etc/rsyslog.d/*.conf

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

# 3. Vytvorte adresáre a súbory s správnymi právami
echo "Vytváram adresáre a súbory..."
sudo mkdir -p /opt/monitoring/logs
sudo mkdir -p /opt/monitoring/kernel
sudo mkdir -p /opt/monitoring/hardware
sudo mkdir -p /opt/monitoring/performance

# 4. Nastavte práva pre rsyslog (syslog:adm)
echo "Nastavujem práva pre rsyslog..."
sudo chown -R syslog:adm /opt/monitoring/
sudo chmod -R 755 /opt/monitoring/

# 5. Vytvorte log súbory
echo "Vytváram log súbory..."
sudo touch /opt/monitoring/logs/all.log
sudo touch /opt/monitoring/logs/critical.log
sudo touch /opt/monitoring/logs/errors.log
sudo touch /opt/monitoring/logs/warnings.log
sudo touch /opt/monitoring/logs/docker.log
sudo touch /opt/monitoring/logs/kubernetes.log
sudo touch /opt/monitoring/logs/ssh.log
sudo touch /opt/monitoring/kernel/kernel.log

# 6. Nastavte práva na súbory
echo "Nastavujem práva na súbory..."
sudo chown syslog:adm /opt/monitoring/logs/*.log
sudo chown syslog:adm /opt/monitoring/kernel/*.log
sudo chmod 640 /opt/monitoring/logs/*.log
sudo chmod 640 /opt/monitoring/kernel/*.log

# 7. Reštart rsyslog
echo "Reštartujem rsyslog..."
sudo systemctl restart rsyslog

# 8. Test
echo "Testujem rsyslog..."
sudo logger -t TEST "Test message from cleanup script"
sleep 2

# 9. Kontrola
echo "Kontrolujem výsledok..."
if [[ -f /opt/monitoring/logs/all.log ]]; then
    echo "✅ all.log existuje:"
    sudo tail -3 /opt/monitoring/logs/all.log
else
    echo "❌ all.log stále neexistuje"
fi

echo "Vyčistenie dokončené!" 