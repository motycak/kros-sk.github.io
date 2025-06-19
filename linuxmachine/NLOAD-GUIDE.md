# Návod na použitie nload pre detekciu sieťového bottlenecku

## Čo je nload?

`nload` je konzolový nástroj pre monitorovanie sieťového provozu v reálnom čase. Zobrazuje grafické grafy pre rýchlosť sťahovania a odosielania dát cez sieťové rozhrania.

## Inštalácia

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nload

# CentOS/RHEL
sudo yum install nload

# Overenie inštalácie
nload --version
```

## Základné použitie

### 1. Monitorovanie všetkých sieťových rozhraní
```bash
nload
```

### 2. Monitorovanie konkrétneho rozhrania
```bash
nload eth0
nload wlan0
nload ens33
```

### 3. Získanie názvu sieťového rozhrania
```bash
# Zobraziť všetky rozhrania
ip addr show

# Zobraziť len názvy rozhraní
ip addr show | grep -E "^[0-9]+:" | awk '{print $2}' | sed 's/://'

# Zobraziť hlavné rozhranie (default gateway)
ip route | grep default | awk '{print $5}'
```

## Pokročilé možnosti

### 1. Nastavenie update intervalu
```bash
nload -t 1000 eth0    # Update každú 1 sekundu
nload -t 500 eth0     # Update každých 0.5 sekundy
nload -t 2000 eth0    # Update každé 2 sekundy
```

### 2. Nastavenie jednotiek
```bash
nload -u B eth0       # Bytes za sekundu
nload -u K eth0       # Kilobytes za sekundu
nload -u M eth0       # Megabytes za sekundu
nload -u G eth0       # Gigabytes za sekundu
```

### 3. Kombinované nastavenia
```bash
nload -t 1000 -u M eth0    # MB/s, update každú 1s
nload -t 500 -u K eth0     # KB/s, update každých 0.5s
```

## Interpretácia výsledkov

### Grafické zobrazenie
```
Device eth0 [192.168.1.100] (1/2):
================================================================================
Incoming:
                                                          Curr: 2.07 MBit/s
                                                          Avg: 1.41 MBit/s
                                                          Min: 0.00 MBit/s
                                                          Max: 3.12 MBit/s
                                                          Ttl: 1.67 GByte
Outgoing:
                                                          Curr: 1.23 MBit/s
                                                          Avg: 0.89 MBit/s
                                                          Min: 0.00 MBit/s
                                                          Max: 2.45 MBit/s
                                                          Ttl: 0.98 GByte
```

### Čo znamenajú hodnoty:
- **Curr**: Aktuálna rýchlosť
- **Avg**: Priemerná rýchlosť za celé obdobie
- **Min**: Minimálna rýchlosť
- **Max**: Maximálna rýchlosť
- **Ttl**: Celkový objem prenesených dát

## Detekcia bottlenecku

### 1. Základný test
```bash
# Spust nload a potom spust build
nload -t 1000 -u M eth0

# V druhom termináli spust build a sleduj zmeny
```

### 2. Paralelné testovanie
```bash
# Spust paralelné sťahovania a sleduj sieť
for i in {1..5}; do
    curl -o /dev/null -s "https://speed.cloudflare.com/__down?bytes=10485760" &
done

# Sleduj nload v druhom termináli
nload -t 1000 -u M eth0
```

### 3. Porovnanie s tvojím problémom

**Tvoj problém:**
- Git checkout: 13 MB/s → 100-200 KB/s (pokles o ~99%)

**Čo hľadať v nload:**
- Ak sa rýchlosť znížila podobne = **sieťový bottleneck**
- Ak sa rýchlosť znížila mierne = **normálne správanie**
- Ak sa rýchlosť nezmenila = **sieť nie je problém**

## Praktické príklady

### Príklad 1: Monitorovanie počas buildu
```bash
# Terminál 1: Spust nload
nload -t 1000 -u M eth0

# Terminál 2: Spust build a sleduj zmeny
kubectl get pods -n build-agents
```

### Príklad 2: Test rýchlosti sťahovania
```bash
# Test rýchlosti pred buildom
curl -w "Rýchlosť: %{speed_download} bytes/sec\n" -o /dev/null -s https://speed.cloudflare.com/__down?bytes=10485760

# Spust nload a sleduj počas buildu
nload -t 1000 -u M eth0

# Test rýchlosti po buildi
curl -w "Rýchlosť: %{speed_download} bytes/sec\n" -o /dev/null -s https://speed.cloudflare.com/__down?bytes=10485760
```

### Príklad 3: Kontinuálne monitorovanie
```bash
# Monitorovanie s automatickým ukončením po 60 sekundách
timeout 60s nload -t 1000 -u M eth0

# Alebo v slučke
while true; do
    nload -t 1000 -u M eth0
    sleep 5
done
```

## Kombinácia s ďalšími nástrojmi

### 1. nload + iotop (disk I/O)
```bash
# Terminál 1: Sieť
nload -t 1000 -u M eth0

# Terminál 2: Disk
sudo iotop -b -n 1
```

### 2. nload + htop (CPU/RAM)
```bash
# Terminál 1: Sieť
nload -t 1000 -u M eth0

# Terminál 2: CPU/RAM
htop
```

### 3. nload + iftop (detailné pripojenia)
```bash
# Terminál 1: Celkový sieťový provoz
nload -t 1000 -u M eth0

# Terminál 2: Detailné pripojenia
sudo iftop -i eth0
```

## Automatické skripty

### Skript 1: Základný monitoring
```bash
#!/bin/bash
echo "=== SIEŤOVÝ MONITORING ==="
echo "Dátum: $(date)"
echo ""

# Získanie hlavného rozhrania
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo "Monitorujem rozhranie: $INTERFACE"
echo ""

# Spustenie nload
nload -t 1000 -u M $INTERFACE
```

### Skript 2: Test s paralelnými sťahovaniami
```bash
#!/bin/bash
echo "=== PARALELNÉ TESTOVANIE ==="

# Spustenie paralelných curl
for i in {1..3}; do
    curl -o /dev/null -s "https://speed.cloudflare.com/__down?bytes=52428800" &
    echo "Sťahovanie $i spustené"
done

# Monitorovanie
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
nload -t 1000 -u M $INTERFACE

# Čakanie na dokončenie
wait
echo "Test dokončený"
```

## Riešenie problémov

### Problém 1: nload sa nespustí
```bash
# Kontrola dostupnosti
which nload

# Inštalácia ak chýba
sudo apt install nload
```

### Problém 2: Nevidím správne rozhranie
```bash
# Zobraziť všetky rozhrania
ip addr show

# Test s konkrétnym rozhraním
nload eth0
nload ens33
nload wlan0
```

### Problém 3: Nízke hodnoty
```bash
# Skontroluj jednotky
nload -u B eth0    # Bytes
nload -u K eth0    # Kilobytes
nload -u M eth0    # Megabytes

# Skontroluj update interval
nload -t 500 -u M eth0    # Rýchlejší update
```

## Záver

`nload` je výborný nástroj pre rýchlu identifikáciu sieťového bottlenecku. Kombinuj ho s `iotop` (disk I/O) a `htop` (CPU/RAM) pre kompletnú diagnózu.

**Kľúčové body:**
- Sleduj zmeny rýchlosti počas buildov
- Porovnaj s tvojím problémom (13 MB/s → 100-200 KB/s)
- Ak sa sieť správa podobne = sieťový problém
- Ak sa sieť správa normálne = problém je inde (disk/CPU/RAM) 