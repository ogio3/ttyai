#!/bin/sh
# ttyai init — PID 1 (Online edition)
# There is no shell. There is no escape.

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /dev/shm
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /run

# === Display Setup ===
# Load DRM dependency chain, then virtio_gpu (must be fb0 — no simpledrm)
for mod in virtio_pci virtio_mmio i2c_core drm drm_kms_helper drm_shmem_helper drm_buddy \
           virtio_gpu \
           fb_sys_fops sysimgblt sysfillrect syscopyarea fbcon \
           xhci_pci xhci_hcd usbhid hid_generic evdev \
           virtio_blk virtio_net virtio_console; do
    modprobe "$mod" 2>/dev/null || true
done

sleep 1

# Set hostname
hostname ttyai

# Setup environment
export TERM=linux
export HOME=/root
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export SSL_CERT_FILE=/etc/ssl/cert.pem
export NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem

# Setup networking (non-interactive, runs as PID 1)
ip link set lo up
NETDEV=""
TRIES=0
while [ -z "$NETDEV" ] && [ $TRIES -lt 10 ]; do
    for iface in $(ls /sys/class/net/ 2>/dev/null); do
        case "$iface" in lo) continue ;; esac
        NETDEV="$iface"
        break
    done
    [ -z "$NETDEV" ] && { TRIES=$((TRIES + 1)); sleep 1; }
done

if [ -n "$NETDEV" ]; then
    ip link set "$NETDEV" up
    udhcpc -i "$NETDEV" -q -s /usr/share/udhcpc/default.script 2>/dev/null
    if ! wget -q -O /dev/null http://registry.npmjs.org/ 2>/dev/null; then
        sleep 2
        udhcpc -i "$NETDEV" -q -s /usr/share/udhcpc/default.script 2>/dev/null
    fi
fi

# Hand off to interactive shell with controlling terminal
# getty establishes a proper controlling terminal (TIOCSCTTY)
exec setsid /sbin/getty -n -l /init-interactive 38400 tty1 linux
