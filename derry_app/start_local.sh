#!/bin/bash
# ─────────────────────────────────────────────
#  Household App — Lokal Geliştirme Başlatıcı
# ─────────────────────────────────────────────
set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}"
echo "  🏠 Household App — Lokal Geliştirme"
echo "─────────────────────────────────────────"
echo -e "${NC}"

# ── Gereksinim kontrolleri ──
check() {
  if ! command -v "$1" &> /dev/null; then
    echo -e "${RED}✗ '$1' bulunamadı. Lütfen kur: $2${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ $1${NC}"
}

echo "Gereksinimler kontrol ediliyor..."
check flutter    "https://flutter.dev/docs/get-started/install"
check firebase   "npm install -g firebase-tools"
check java       "https://adoptium.net  (Java 11+ gerekli)"
echo ""

# ── Flutter bağımlılıkları ──
echo -e "${YELLOW}→ flutter pub get${NC}"
flutter pub get

# ── Emulatorları arka planda başlat ──
echo ""
echo -e "${YELLOW}→ Firebase Emulators başlatılıyor (demo-household)...${NC}"
firebase emulators:start --project demo-household \
  --import=./emulator_data \
  --export-on-exit=./emulator_data &
EMULATOR_PID=$!

# Emulatorların hazır olmasını bekle
echo -n "Emulatorlar hazırlanıyor"
for i in {1..15}; do
  sleep 1
  echo -n "."
  # Firestore emulator hazır mı?
  if curl -s http://localhost:8080 > /dev/null 2>&1; then
    break
  fi
done
echo ""

# ── Seed verisi yükle (ilk çalıştırmada) ──
if [ ! -d "./emulator_data" ]; then
  echo -e "${YELLOW}→ İlk çalıştırma: seed verisi yükleniyor...${NC}"
  node -e "
const fetch = require('node-fetch');
const data = require('./emulator_seed.json').seed_data;

const PROJECT = 'demo-household';
const BASE = 'http://localhost:8080/v1/projects/' + PROJECT + '/databases/(default)/documents';

async function seed() {
  for (const [col, docs] of Object.entries(data)) {
    for (const [docId, fields] of Object.entries(docs)) {
      const firestoreFields = {};
      for (const [k, v] of Object.entries(fields)) {
        if (typeof v === 'string')  firestoreFields[k] = { stringValue: v };
        if (typeof v === 'boolean') firestoreFields[k] = { booleanValue: v };
      }
      await fetch(BASE + '/' + col + '/' + docId + '?currentDocument.exists=false', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fields: firestoreFields })
      });
      console.log('Seeded: ' + col + '/' + docId);
    }
  }
}
seed().catch(console.error);
  " 2>/dev/null || echo -e "${YELLOW}  (seed scripti atlandı — Emulator UI'dan manuel ekleyebilirsin)${NC}"
fi

echo ""
echo -e "${GREEN}✓ Firebase Emulators çalışıyor:${NC}"
echo "  Emulator UI   → http://localhost:4000"
echo "  Firestore     → http://localhost:8080"
echo "  Auth          → http://localhost:9099"
echo "  Storage       → http://localhost:9199"
echo ""

# ── Flutter web ──
echo -e "${YELLOW}→ Flutter web başlatılıyor...${NC}"
echo "  Uygulama      → http://localhost:3000"
echo ""
echo -e "  ${CYAN}İlk giriş anahtarı: HM-INIT-LOCAL${NC}"
echo ""

flutter run -d web-server \
  --web-port 3000 \
  --web-hostname localhost \
  --dart-define=FLUTTER_WEB_AUTO_DETECT=true

# Çıkışta emulatorları durdur
kill $EMULATOR_PID 2>/dev/null || true
echo -e "${GREEN}✓ Emulatorlar durduruldu.${NC}"
