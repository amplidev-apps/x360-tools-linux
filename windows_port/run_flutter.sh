#!/bin/bash
# x360 Tools for Linux v2.0 - Flutter Engine Launcher

# Ensure Flutter is in PATH (assuming standard installation from previous step)
export PATH="$PATH:$HOME/flutter_sdk/bin"

echo "[*] x360 Tools for Linux v2.0 — Iniciando Interface Premium (Flutter)..."

# Change to the flutter project directory
cd "$(dirname "$0")/x360_tools_flutter"

# Run the app in release mode for best performance, or debug for first run
# We use debug here so the user can see logs if needed
flutter run -d linux
