#!/bin/bash
# Skript pre testovanie sieťovej dostupnosti Alfa NuGet servera

set -e

ALFA_SERVER="sefiskompil2"
ALFA_SHARE="NugetServer ALFAplus"

echo "=== Testovanie sieťovej dostupnosti Alfa NuGet servera ==="

# 1. Ping test
echo "1. Ping test na $ALFA_SERVER:"
if ping -c 3 "$ALFA_SERVER" > /dev/null 2>&1; then
    echo "   ✅ Server $ALFA_SERVER je dostupný cez ping"
else
    echo "   ❌ Server $ALFA_SERVER nie je dostupný cez ping"
fi

# 2. Port test (SMB porty)
echo "2. Test SMB portov na $ALFA_SERVER:"
SMB_PORTS=(139 445)
for port in "${SMB_PORTS[@]}"; do
    if timeout 5 bash -c "</dev/tcp/$ALFA_SERVER/$port" 2>/dev/null; then
        echo "   ✅ Port $port je otvorený"
    else
        echo "   ❌ Port $port nie je dostupný"
    fi
done

# 3. SMB list test
echo "3. Test SMB zoznamu shares:"
if command -v smbclient > /dev/null 2>&1; then
    if timeout 10 smbclient -L "//$ALFA_SERVER" -U guest% 2>/dev/null | grep -q "$ALFA_SHARE"; then
        echo "   ✅ Share '$ALFA_SHARE' je dostupný"
    else
        echo "   ❌ Share '$ALFA_SHARE' nie je dostupný alebo nie je viditeľný"
    fi
else
    echo "   ⚠️  smbclient nie je nainštalovaný"
fi

# 4. Priamy mount test
echo "4. Test priameho mountovania:"
TEST_MOUNT="/tmp/test-alfa-mount"
if [ -d "$TEST_MOUNT" ]; then
    sudo umount "$TEST_MOUNT" 2>/dev/null || true
    sudo rmdir "$TEST_MOUNT" 2>/dev/null || true
fi

sudo mkdir -p "$TEST_MOUNT"
if sudo mount -t cifs "//$ALFA_SERVER/$ALFA_SHARE" "$TEST_MOUNT" -o username=guest,iocharset=utf8 2>/dev/null; then
    echo "   ✅ Úspešne mountovaný na $TEST_MOUNT"
    echo "   Obsah:"
    ls -la "$TEST_MOUNT" | head -10
    sudo umount "$TEST_MOUNT"
    sudo rmdir "$TEST_MOUNT"
else
    echo "   ❌ Nepodarilo sa mountovať"
fi

echo "=== Testovanie dokončené ===" 