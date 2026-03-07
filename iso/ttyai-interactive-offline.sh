#!/bin/sh
# ttyai interactive — offline edition (OpenCode + Ollama)

export TERM=linux
export HOME=/root
stty sane 2>/dev/null
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export OLLAMA_HOST=http://127.0.0.1:11434
export OPENAI_API_BASE=http://127.0.0.1:11434/v1
export OPENAI_API_KEY=ollama

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
echo "  AI:      OpenCode + Ollama"
echo "  Mode:    OFFLINE"
echo "  Escape:  IMPOSSIBLE"
echo ""

# Wait for Ollama to be ready
echo "  Waiting for Ollama..."
TRIES=0
while [ $TRIES -lt 30 ]; do
    if wget -q -O /dev/null http://127.0.0.1:11434/api/tags 2>/dev/null; then
        break
    fi
    TRIES=$((TRIES + 1))
    sleep 1
done

if [ $TRIES -eq 30 ]; then
    echo "  WARNING: Ollama server may not be ready."
else
    echo "  Ollama ready."
fi

echo ""
echo "  Launching. Good luck."
echo ""
sleep 1

# Launch — infinite loop, no escape
while true; do
    opencode || {
        echo ""
        echo "  AI CLI exited. Restarting in 3 seconds..."
        echo "  (There is no escape.)"
        sleep 3
    }
done
