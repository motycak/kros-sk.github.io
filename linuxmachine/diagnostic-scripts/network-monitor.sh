#!/bin/bash

# Sieťový monitorovací skript pre identifikáciu bottlenecku
# Používa nload, iftop, ss a ďalšie nástroje na analýzu sieťového provozu

echo "=== SIEŤOVÝ MONITORING PRE BOTTLENECK DIAGNÓZU ==="
echo "Dátum: $(date)"
echo ""

# 1. Kontrola dostupnosti nload
if ! command -v nload &> /dev/null; then
    echo "❌ nload nie je nainštalovaný"
    echo "📦 Inštalácia: sudo apt install nload"
    echo ""
    exit 1
fi

echo "✅ nload je dostupný"
echo ""

# 2. Získanie sieťových rozhraní
echo "=== SIEŤOVÉ ROZHRANIA ==="
echo "Aktívne sieťové rozhrania:"
ip addr show | grep -E "^[0-9]+:" | awk '{print $2}' | sed 's/://'
echo ""

# 3. Základné sieťové informácie
echo "=== ZÁKLADNÉ SIEŤOVÉ INFORMÁCIE ==="
echo "Default gateway:"
ip route | grep default
echo ""

echo "DNS servery:"
cat /etc/resolv.conf | grep nameserver
echo ""

# 4. Test rýchlosti sťahovania
echo "=== TEST RÝCHLOSTI SŤAHOVANIA ==="
echo "Test 1: Cloudflare speed test (10MB)"
curl -w "Rýchlosť: %{speed_download} bytes/sec (%.2f MB/s)\n" -o /dev/null -s https://speed.cloudflare.com/__down?bytes=10485760

echo "Test 2: Azure DevOps (ak je dostupné)"
curl -w "Rýchlosť: %{speed_download} bytes/sec (%.2f MB/s)\n" -o /dev/null -s https://dev.azure.com/krossk/_apis/project/ 2>/dev/null || echo "Azure DevOps nie je dostupné"

echo "Test 3: GitHub (pre Git operácie)"
curl -w "Rýchlosť: %{speed_download} bytes/sec (%.2f MB/s)\n" -o /dev/null -s https://github.com/microsoft/azure-pipelines-agent/archive/refs/heads/master.zip
echo ""

# 5. Aktívne sieťové pripojenia
echo "=== AKTÍVNE SIEŤOVÉ PRIPOJENIA ==="
echo "Počet aktívnych TCP pripojení:"
ss -tuln | grep ESTABLISHED | wc -l

echo "Top 5 najaktívnejších pripojení (podľa portov):"
ss -tuln | grep ESTABLISHED | awk '{print $5}' | cut -d: -f2 | sort | uniq -c | sort -nr | head -5
echo ""

# 6. Kubernetes sieťové pripojenia
echo "=== KUBERNETES SIEŤOVÉ PRIPOJENIA ==="
echo "Pody v build-agents namespace:"
kubectl get pods -n build-agents -o name 2>/dev/null | head -5 | while read pod; do
    echo "Pod: $pod"
    kubectl exec -n build-agents $pod -- ss -tuln 2>/dev/null | grep ESTABLISHED | head -3 || echo "  Nepodarilo sa získať sieťové informácie"
    echo ""
done

# 7. Návod na použitie nload
echo "=== NÁVOD NA POUŽITIE NLOAD ==="
echo "📊 Pre kontinuálne monitorovanie sieťového provozu:"
echo "   nload [sieťové_rozhranie]"
echo ""
echo "📊 Príklady:"
echo "   nload eth0                    # Monitorovanie eth0"
echo "   nload -t 1000 eth0            # Update každú 1 sekundu"
echo "   nload -u B eth0               # Zobraziť v bytes/s"
echo "   nload -u M eth0               # Zobraziť v MB/s"
echo ""

# 8. Ďalšie užitočné nástroje
echo "=== ĎALŠIE UŽITOČNÉ NÁSTROJE ==="
echo "📊 iftop - interaktívny sieťový monitor:"
echo "   sudo apt install iftop"
echo "   sudo iftop -i eth0"
echo ""

echo "📊 iotop - disk I/O monitoring:"
echo "   sudo apt install iotop"
echo "   sudo iotop -b -n 1"
echo ""

echo "📊 htop - CPU/RAM monitoring:"
echo "   sudo apt install htop"
echo "   htop"
echo ""

# 9. Automatický test s nload
echo "=== AUTOMATICKÝ TEST S NLOAD ==="
echo "Spúšťam 10-sekundový test s nload..."
echo ""

# Získanie hlavného sieťového rozhrania
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

if [ ! -z "$MAIN_INTERFACE" ]; then
    echo "Monitorujem rozhranie: $MAIN_INTERFACE"
    echo "Test trvá 10 sekúnd, stlač Ctrl+C pre ukončenie..."
    echo ""
    
    # Spustenie nload na 10 sekúnd
    timeout 10s nload -t 1000 -u M $MAIN_INTERFACE 2>/dev/null || echo "nload test dokončený"
else
    echo "❌ Nepodarilo sa identifikovať hlavné sieťové rozhranie"
fi

echo ""
echo "=== INTERPRETÁCIA VÝSLEDKOV ==="
echo "🔍 Čo hľadať v nload výstupe:"
echo "   • Vysoká rýchlosť sťahovania (>100 MB/s) = sieť je OK"
echo "   • Nízka rýchlosť sťahovania (<10 MB/s) = sieťový bottleneck"
echo "   • Vysoká rýchlosť odosielania = možný problém s uploadom"
echo "   • Konzistentné využitie = normálne"
echo "   • Špičky v využití = paralelné sťahovania"
echo ""

echo "🔍 Ak je sieť OK, problém je pravdepodobne:"
echo "   • Disk I/O (použi iotop)"
echo "   • CPU bottleneck (použi htop)"
echo "   • RAM nedostatok (použi free -h)"
echo ""

echo "=== HOTOVO ==="
echo "Pre detailnejšiu analýzu spust:"
echo "   nload -t 1000 -u M [rozhranie]  # Kontinuálne monitorovanie"
echo "   sudo iftop -i [rozhranie]       # Detailné pripojenia"
echo "   sudo iotop -b -n 1              # Disk I/O" 