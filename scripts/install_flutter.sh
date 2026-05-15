#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Instalando Flutter..."

FLUTTER_DIR="$HOME/flutter"

# Clonar Flutter solo si no existe
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# Habilitar web y precache
flutter config --enable-web
flutter precache --web

echo "✅ Flutter instalado correctamente"
flutter --version