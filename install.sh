#!/usr/bin/env bash
set -euo pipefail

# kokoro-tts-mpv installer
# Sets up venv, installs dependencies, symlinks scripts and mpv plugin

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }
step()  { echo -e "\n${BOLD}→ $*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Preflight ---
step "Checking requirements..."

if ! command -v python3 &>/dev/null; then
    error "python3 not found"
    exit 1
fi
info "python3 found"

if ! command -v socat &>/dev/null; then
    error "socat not found. Install it:"
    echo "  Fedora: sudo dnf install socat"
    echo "  Ubuntu: sudo apt install socat"
    echo "  Arch:   sudo pacman -S socat"
    exit 1
fi
info "socat found"

if ! command -v paplay &>/dev/null; then
    warn "paplay not found — audio playback may not work"
fi

# --- Create venv ---
step "Setting up Python virtual environment..."

VENV="$SCRIPT_DIR/.venv"
if [[ ! -d "$VENV" ]]; then
    python3 -m venv "$VENV"
    info "Created venv at $VENV"
else
    info "Venv already exists"
fi

# --- Install Python deps ---
step "Installing Python dependencies..."

source "$VENV/bin/activate"
pip install --upgrade pip -q
pip install kokoro soundfile numpy -q 2>&1 | tail -3
info "Python dependencies installed"
deactivate

# --- Make scripts executable ---
chmod +x "$SCRIPT_DIR/scripts/kokoro-tts-start"
chmod +x "$SCRIPT_DIR/scripts/kokoro-speak"

# --- Symlink scripts to ~/.local/bin ---
step "Symlinking scripts..."

mkdir -p "$HOME/.local/bin"
ln -sf "$SCRIPT_DIR/scripts/kokoro-speak" "$HOME/.local/bin/kokoro-speak"
ln -sf "$SCRIPT_DIR/scripts/kokoro-tts-start" "$HOME/.local/bin/kokoro-tts-start"
info "kokoro-speak → ~/.local/bin/"
info "kokoro-tts-start → ~/.local/bin/"

# --- Symlink mpv script ---
step "Installing mpv plugin..."

mkdir -p "$HOME/.config/mpv/scripts"
ln -sf "$SCRIPT_DIR/mpv/sub-tts.lua" "$HOME/.config/mpv/scripts/sub-tts.lua"
info "sub-tts.lua → ~/.config/mpv/scripts/"

# --- Done ---
echo ""
echo -e "${BOLD}${GREEN}✓ kokoro-tts-mpv installed!${NC}"
echo ""
echo "  Usage:"
echo "    1. Open a video:  mpv \"https://youtube.com/watch?v=...\""
echo "    2. Press Ctrl+t to toggle subtitle TTS"
echo "    3. Daemon loads on first use (~5 sec), shuts down when mpv exits"
echo ""
echo "  The TTS daemon only runs while mpv is open — zero RAM when idle."
echo ""
