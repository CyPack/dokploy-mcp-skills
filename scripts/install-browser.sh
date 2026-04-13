#!/bin/bash
# Browser kurulum scripti - Playwright MCP için

echo "🌐 Chromium yükleniyor..."
sudo dnf install -y chromium

# Symlink oluştur - Playwright /opt/google/chrome/chrome arıyor
echo "🔗 Symlink oluşturuluyor..."
sudo mkdir -p /opt/google/chrome
sudo ln -sf /usr/bin/chromium-browser /opt/google/chrome/chrome 2>/dev/null || \
sudo ln -sf /usr/bin/chromium /opt/google/chrome/chrome

echo "✅ Kurulum tamamlandı!"
echo "Kontrol: /opt/google/chrome/chrome --version"
/opt/google/chrome/chrome --version 2>/dev/null || chromium --version
