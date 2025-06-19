#!/bin/bash

# Paralelné testovanie sieťového výkonu počas aktívnych buildov
# Pomáha identifikovať, či je bottleneck v sieti alebo v inom komponente

echo "=== PARALELNÉ SIEŤOVÉ TESTOVANIE ==="
echo "Tento skript testuje sieťový výkon počas aktívnych buildov"
echo "Dátum: $(date)"
echo ""

# Kontrola dostupnosti nload
if ! command -v nload &> /dev/null; then
    echo "❌ nload nie je nainštalovaný"
    echo "📦 Inštalácia: sudo apt install nload"
    exit 1
fi

# Získanie hlavného sieťového rozhrania
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

if [ -z "$MAIN_INTERFACE" ]; then
    echo "❌ Nepodarilo sa identifikovať hlavné sieťové rozhranie"
    exit 1
fi

echo "✅ Monitorujem rozhranie: $MAIN_INTERFACE"
echo ""

# Funkcia pre test rýchlosti
test_speed() {
    local test_name="$1"
    local url="$2"
    local size="$3"
    
    echo "🧪 Test: $test_name"
    local speed=$(curl -w "%{speed_download}" -o /dev/null -s "$url" 2>/dev/null)
    local speed_mb=$(echo "scale=2; $speed / 1048576" | bc -l 2>/dev/null || echo "0")
    echo "   Rýchlosť: ${speed_mb} MB/s"
    echo ""
}

# Funkcia pre monitorovanie buildov
monitor_builds() {
    echo "🔍 Monitorovanie aktívnych buildov..."
    kubectl get pods -n build-agents -o wide 2>/dev/null | grep Running | wc -l
}

echo "=== FÁZA 1: ZÁKLADNÝ TEST (bez aktívnych buildov) ==="
echo "Počet aktívnych build agentov: $(monitor_builds)"
echo ""

# Základné testy rýchlosti
test_speed "Cloudflare Speed Test" "https://speed.cloudflare.com/__down?bytes=10485760" "10MB"
test_speed "GitHub Download" "https://github.com/microsoft/azure-pipelines-agent/archive/refs/heads/master.zip" "~1MB"

echo "=== FÁZA 2: PARALELNÉ TESTOVANIE ==="
echo "Teraz spustím paralelné sťahovania a budem monitorovať sieť..."
echo ""

# Spustenie paralelných curl testov na pozadí
echo "🚀 Spúšťam paralelné sťahovania..."
for i in {1..5}; do
    curl -o /dev/null -s "https://speed.cloudflare.com/__down?bytes=52428800" &
    echo "   Sťahovanie $i spustené (PID: $!)"
done

echo ""
echo "📊 Monitorovanie sieťového provozu počas paralelných sťahovaní..."
echo "Stlač Ctrl+C pre ukončenie monitorovania"
echo ""

# Spustenie nload na monitorovanie
nload -t 1000 -u M $MAIN_INTERFACE

# Čakanie na dokončenie všetkých curl procesov
echo ""
echo "⏳ Čakám na dokončenie všetkých sťahovaní..."
wait

echo ""
echo "=== FÁZA 3: ANALÝZA VÝSLEDKOV ==="
echo ""

# Test rýchlosti po paralelných sťahovaniach
echo "🧪 Test rýchlosti po paralelných sťahovaniach:"
test_speed "Cloudflare Speed Test" "https://speed.cloudflare.com/__down?bytes=10485760" "10MB"

echo "=== INTERPRETÁCIA VÝSLEDKOV ==="
echo ""
echo "🔍 Čo si všimnúť v nload výstupe:"
echo "   • Ak sa rýchlosť znížila výrazne = sieťový bottleneck"
echo "   • Ak sa rýchlosť znížila mierne = normálne správanie"
echo "   • Ak sa rýchlosť nezmenila = sieť nie je problém"
echo ""

echo "🔍 Porovnanie s tvojím problémom:"
echo "   • Git checkout: 13 MB/s → 100-200 KB/s"
echo "   • To je pokles o ~99%"
echo "   • Ak nload ukazuje podobný pokles = sieťový problém"
echo "   • Ak nload je OK = problém je v disku/CPU/RAM"
echo ""

echo "=== ĎALŠIE KROKY ==="
echo "1. Ak je sieť OK, spust: sudo iotop -b -n 1"
echo "2. Ak je sieť problém, skontroluj:"
echo "   • ISP throttling"
echo "   • Firewall obmedzenia"
echo "   • Router QoS nastavenia"
echo "3. Pre detailnejšiu analýzu: sudo iftop -i $MAIN_INTERFACE"
echo ""

echo "=== HOTOVO ===" 