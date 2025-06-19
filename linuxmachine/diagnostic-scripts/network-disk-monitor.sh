#!/bin/bash

# Diagnostický skript pre identifikáciu bottlenecku na Linux build machine
# Používa sa na monitorovanie sieťového a diskového I/O pri paralelných buildoch

echo "=== DIAGNOSTIKA BOTTLENECKU NA BUILD MACHINE ==="
echo "Dátum: $(date)"
echo ""

# 1. Základné informácie o systéme
echo "=== SYSTÉMOVÉ INFORMÁCIE ==="
echo "CPU: $(nproc) jadier"
echo "RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $2}')"
echo ""

# 2. Aktuálne využitie CPU a RAM
echo "=== AKTUÁLNE VYUŽITIE ==="
echo "CPU load: $(uptime | awk -F'load average:' '{print $2}')"
echo "RAM využitie:"
free -h
echo ""

# 3. Sieťové pripojenia a rýchlosť
echo "=== SIEŤOVÉ INFORMÁCIE ==="
echo "Aktívne sieťové pripojenia:"
ss -tuln | grep LISTEN | head -10
echo ""

# Test rýchlosti sťahovania (ak je curl dostupné)
if command -v curl &> /dev/null; then
    echo "Test rýchlosti sťahovania (10MB):"
    curl -w "Rýchlosť: %{speed_download} bytes/sec\n" -o /dev/null -s https://speed.cloudflare.com/__down?bytes=10485760
    echo ""
fi

# 4. Disk I/O monitoring
echo "=== DISK I/O MONITORING ==="
echo "Aktuálne disk I/O (iotop -b -n 1):"
if command -v iotop &> /dev/null; then
    iotop -b -n 1 | head -15
else
    echo "iotop nie je nainštalovaný. Inštalujte: sudo apt install iotop"
fi
echo ""

# 5. Kubernetes pody a ich resource využitie
echo "=== KUBERNETES PODY ==="
echo "Aktívne pody v namespace build-agents:"
kubectl get pods -n build-agents -o wide
echo ""

echo "Resource využitie podov:"
kubectl top pods -n build-agents 2>/dev/null || echo "Metrics server nie je dostupný"
echo ""

# 6. PVC a storage informácie
echo "=== STORAGE INFORMÁCIE ==="
echo "PVC stav:"
kubectl get pvc -n build-agents
echo ""

echo "Storage class informácie:"
kubectl get storageclass
echo ""

# 7. Sieťové pripojenia z podov
echo "=== SIEŤOVÉ PRIPOJENIA Z PODOV ==="
echo "Aktívne sieťové pripojenia z build-agents namespace:"
kubectl get pods -n build-agents -o name | head -5 | while read pod; do
    echo "Pod: $pod"
    kubectl exec -n build-agents $pod -- ss -tuln 2>/dev/null | grep ESTABLISHED | head -3 || echo "  Nepodarilo sa získať sieťové informácie"
    echo ""
done

# 8. Git cache a artefakt cache veľkosti
echo "=== CACHE VEĽKOSTI ==="
echo "Veľkosti cache adresárov v PVC:"
kubectl get pods -n build-agents -o name | head -1 | while read pod; do
    if [ ! -z "$pod" ]; then
        echo "Cache veľkosti z podu $pod:"
        kubectl exec -n build-agents $pod -- du -sh /opt/Agents/cache/* 2>/dev/null || echo "  Nepodarilo sa získať cache informácie"
    fi
done
echo ""

echo "=== DIAGNÓZA HOTOVÁ ==="
echo "Pre kontinuálne monitorovanie spustite:"
echo "watch -n 5 './network-disk-monitor.sh'" 