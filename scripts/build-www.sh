#!/usr/bin/env bash
# Prepara la cartella www/ che Capacitor impacchetta nell'app nativa.
# Copia i file web dell'app (gli stessi che girano su GitHub Pages) in www/,
# più il bridge nativo (native.js) che collega Capacitor all'app esistente.
set -e
cd "$(dirname "$0")/.."

echo "🧹 Pulisco www/…"
rm -rf www
mkdir -p www/icons www/supabase

echo "📄 Copio i file web…"
cp index.html www/
cp styles.css www/
cp manifest.json www/
cp sw.js www/
cp -r icons/* www/icons/ 2>/dev/null || true

# Iniezione del bridge nativo: aggiunge <script src="native.js"> prima di </body>
# solo se non è già presente.
if ! grep -q 'native.js' www/index.html; then
  echo "🔌 Inietto il bridge nativo (native.js)…"
  # inserisce lo script subito prima della chiusura del body
  perl -0pi -e 's{</body>}{  <script src="native.js"></script>\n</body>}' www/index.html
fi

cp scripts/native.js www/native.js

echo "✅ www/ pronta."
