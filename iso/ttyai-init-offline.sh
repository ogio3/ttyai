#!/bin/sh
# ttyai init — PID 1 (Offline edition)
# No internet. No API key. No escape. Just local AI.

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /dev/shm
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /run

# Load essential kernel modules
# Display: virtio_gpu only (not simpledrm — it steals fb0 from UTM Display)
for mod in virtio_pci virtio_mmio \
           i2c_core drm drm_kms_helper drm_shmem_helper drm_buddy \
           virtio_gpu \
           fb_sys_fops sysimgblt sysfillrect syscopyarea fbcon \
           xhci_pci xhci_hcd usbhid hid_generic evdev \
           virtio_blk virtio_net virtio_console; do
    modprobe "$mod" 2>/dev/null || true
done

sleep 1

hostname ttyai

# Setup environment
export TERM=linux
export HOME=/root
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export OLLAMA_HOST=http://127.0.0.1:11434

# Start Ollama server in background (needs to be running before interactive)
ollama serve > /tmp/ollama.log 2>&1 &

# Hand off to interactive shell with controlling terminal
exec setsid /sbin/getty -n -l /init-interactive 38400 tty1 linux
