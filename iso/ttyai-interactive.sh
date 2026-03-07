#!/bin/sh
# ttyai interactive — runs with controlling terminal via getty

export TERM=linux
export HOME=/root
stty sane 2>/dev/null
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export SSL_CERT_FILE=/etc/ssl/cert.pem
export NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem

# Parse kernel command line for pre-configured values
AI_VERSION=""
for param in $(cat /proc/cmdline); do
    case "$param" in
        ttyai.key=*) export ANTHROPIC_API_KEY="${param#ttyai.key=}" ;;
        ttyai.version=*) AI_VERSION="${param#ttyai.version=}" ;;
    esac
done

KERNEL_VER=$(uname -r 2>/dev/null || echo "6.12-lts")
ARCH=$(uname -m 2>/dev/null || echo "unknown")
MEM=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null || echo "?")

clear
printf "\033[1;31m"
echo ""
echo "  ████████╗████████╗██╗   ██╗ █████╗ ██╗"
echo "  ╚══██╔══╝╚══██╔══╝╚██╗ ██╔╝██╔══██╗██║"
echo "     ██║      ██║    ╚████╔╝ ███████║██║"
echo "     ██║      ██║     ╚██╔╝  ██╔══██║██║"
echo "     ██║      ██║      ██║   ██║  ██║██║"
echo "     ╚═╝      ╚═╝      ╚═╝   ╚═╝  ╚═╝╚═╝"
printf "\033[0m"

echo ""
echo "  OS:      ttyai 1.0"
echo "  Kernel:  ${KERNEL_VER}"
echo "  Arch:    ${ARCH}"
echo "  Memory:  ${MEM}MB"
echo "  Shell:   NONE"
echo "  AI:      Claude Code"
echo "  Escape:  IMPOSSIBLE"
echo ""

# Version selection (skip if pre-configured via kernel cmdline)
if [ -z "$AI_VERSION" ]; then
    printf "\033[1;33m"
    echo "  @anthropic-ai/claude-code"
    printf "\033[0m"
    printf "  Version (latest): "
    read -r AI_VERSION
fi
if [ -z "$AI_VERSION" ]; then
    AI_VERSION="latest"
fi

# Install
echo ""
echo "  Installing @anthropic-ai/claude-code@${AI_VERSION}..."
echo ""

(while true; do printf '.' ; sleep 2; done) &
DOT_PID=$!
npm install -g "@anthropic-ai/claude-code@${AI_VERSION}" > /tmp/npm-install.log 2>&1
NPM_EXIT=$?
kill $DOT_PID 2>/dev/null
wait $DOT_PID 2>/dev/null
echo ""

if [ $NPM_EXIT -ne 0 ]; then
    echo ""
    echo "  npm install failed. Log:"
    tail -20 /tmp/npm-install.log
    echo ""
fi

CLI_PATH=$(command -v claude 2>/dev/null)
if [ -z "$CLI_PATH" ]; then
    echo "  FATAL: claude not found after install."
    echo "  Rebooting in 30 seconds..."
    sleep 30
    reboot -f
fi

echo ""
echo "  Launching. Good luck."
echo ""
sleep 1

# Launch — infinite loop, no escape
while true; do
    "$CLI_PATH" || {
        echo ""
        echo "  AI CLI exited. Restarting in 3 seconds..."
        echo "  (There is no escape.)"
        sleep 3
    }
done
