#!/bin/sh
# Build ttyai rootfs — unified for online and offline editions
# Usage: build-rootfs.sh [online|offline]
set -e

MODE="${1:-online}"
ROOTFS="/rootfs"

# Create directory structure
for dir in bin sbin usr/bin usr/sbin usr/local/bin usr/local/lib usr/lib lib \
           etc dev proc sys tmp run root var/run; do
    mkdir -p "${ROOTFS}/${dir}"
done

# === Busybox ===
cp -a /bin/busybox "${ROOTFS}/bin/"
for cmd in sh ash mount umount mkdir cat ls cp mv rm ln chmod chown \
           hostname ip udhcpc sleep clear printf awk nproc du find \
           grep sed head tail wc tr cut date echo test expr env \
           kill ps top free df ping wget vi read reboot poweroff \
           setsid getty modprobe depmod; do
    ln -sf busybox "${ROOTFS}/bin/${cmd}" 2>/dev/null || true
done
for cmd in ip route ifconfig reboot modprobe depmod getty; do
    ln -sf ../bin/busybox "${ROOTFS}/sbin/${cmd}" 2>/dev/null || true
done
if [ ! -e "${ROOTFS}/bin/sh" ]; then
    echo "FATAL: /bin/sh missing!"
    exit 1
fi

# === Node.js ===
cp -a /usr/bin/node "${ROOTFS}/usr/bin/"

if [ "$MODE" = "online" ]; then
    # npm (AI CLIs installed at boot time)
    cp -a /usr/bin/npm "${ROOTFS}/usr/bin/" 2>/dev/null || true
    if [ -d /usr/lib/node_modules/npm ]; then
        mkdir -p "${ROOTFS}/usr/lib/node_modules"
        cp -a /usr/lib/node_modules/npm "${ROOTFS}/usr/lib/node_modules/"
    fi
    if [ -f /usr/bin/npx ]; then
        cp -a /usr/bin/npx "${ROOTFS}/usr/bin/" 2>/dev/null || true
    fi
    # /usr/bin/env (needed by npm shebang: #!/usr/bin/env node)
    ln -sf ../../bin/env "${ROOTFS}/usr/bin/env" 2>/dev/null || true
else
    # OpenCode (pre-installed)
    cp -a /usr/local/bin/opencode "${ROOTFS}/usr/local/bin/" 2>/dev/null || true
    cp -a /usr/local/lib/node_modules "${ROOTFS}/usr/local/lib/" 2>/dev/null || true
    # Ollama binary (pre-installed)
    cp -a /usr/local/bin/ollama "${ROOTFS}/usr/local/bin/"
    # Ollama models (pre-downloaded)
    if [ -d /root/.ollama ]; then
        mkdir -p "${ROOTFS}/root"
        cp -a /root/.ollama "${ROOTFS}/root/"
        echo "  Ollama models copied"
    fi
fi

# === Shared libraries ===
for lib in \
    /lib/ld-musl-*.so.* \
    /lib/libz.so* \
    /usr/lib/libz.so* \
    /lib/libcrypto*.so* \
    /lib/libssl*.so* \
    /usr/lib/libssl*.so* \
    /usr/lib/libstdc++.so* \
    /usr/lib/libgcc_s.so* \
    /usr/lib/libicui18n.so* \
    /usr/lib/libicuuc.so* \
    /usr/lib/libicudata.so* \
    /usr/lib/libada.so* \
    /usr/lib/libsimdjson.so* \
    /usr/lib/libsimdutf.so* \
    /usr/lib/libsqlite3.so* \
    /usr/lib/libbrotli*.so* \
    /usr/lib/libcares.so* \
    /usr/lib/libnghttp2.so* \
    /usr/lib/libuv.so* \
    ; do
    for f in $lib; do
        [ -e "$f" ] || continue
        dest="${ROOTFS}${f}"
        mkdir -p "$(dirname "$dest")"
        cp -a "$f" "$dest" 2>/dev/null || true
    done
done

# === Minimal /etc ===
cat > "${ROOTFS}/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/sh
EOF
cat > "${ROOTFS}/etc/group" << 'EOF'
root:x:0:
EOF
cat > "${ROOTFS}/etc/hostname" << 'EOF'
ttyai
EOF
cat > "${ROOTFS}/etc/hosts" << 'EOF'
127.0.0.1 localhost
127.0.0.1 ttyai
EOF

if [ "$MODE" = "online" ]; then
    cat > "${ROOTFS}/etc/resolv.conf" << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
    # ICU data (needed by Node.js for Intl/Unicode)
    if [ -d /usr/share/icu ]; then
        mkdir -p "${ROOTFS}/usr/share/icu"
        cp -a /usr/share/icu/* "${ROOTFS}/usr/share/icu/"
    fi
else
    cat > "${ROOTFS}/etc/resolv.conf" << 'EOF'
nameserver 127.0.0.1
EOF
fi

# SSL certs
if [ -d /etc/ssl ]; then
    mkdir -p "${ROOTFS}/etc/ssl"
    cp -a /etc/ssl/certs "${ROOTFS}/etc/ssl/" 2>/dev/null || true
    cp -a /etc/ssl/cert.pem "${ROOTFS}/etc/ssl/" 2>/dev/null || true
fi

# udhcpc script (online only, but harmless to include)
if [ "$MODE" = "online" ]; then
    mkdir -p "${ROOTFS}/usr/share/udhcpc"
    cat > "${ROOTFS}/usr/share/udhcpc/default.script" << 'DHCP'
#!/bin/sh
case "$1" in
    bound|renew)
        [ -n "$ip" ] && ip addr add "$ip/$mask" dev "$interface"
        [ -n "$router" ] && ip route add default via "$router"
        [ -n "$dns" ] && echo "nameserver $dns" > /etc/resolv.conf
        ;;
esac
DHCP
    chmod +x "${ROOTFS}/usr/share/udhcpc/default.script"
fi

# === Kernel modules ===
KVER=$(ls /lib/modules/ | head -1)
if [ -n "$KVER" ] && [ -d "/lib/modules/${KVER}" ]; then
    echo "Copying kernel modules (${KVER})..."
    mkdir -p "${ROOTFS}/lib/modules/${KVER}"
    for f in /lib/modules/${KVER}/kernel/drivers/net/virtio_net.ko*; do
        [ -e "$f" ] || continue
        dest="${ROOTFS}${f}"
        mkdir -p "$(dirname "$dest")"
        cp -a "$f" "$dest" 2>/dev/null || true
    done
    for f in /lib/modules/${KVER}/kernel/drivers/net/net_failover.ko*; do
        [ -e "$f" ] || continue
        dest="${ROOTFS}${f}"
        mkdir -p "$(dirname "$dest")"
        cp -a "$f" "$dest" 2>/dev/null || true
    done
    for moddir in kernel/drivers/virtio kernel/drivers/net/virtio* \
                  kernel/drivers/i2c \
                  kernel/drivers/gpu/drm \
                  kernel/drivers/video kernel/drivers/char \
                  kernel/drivers/usb kernel/drivers/input kernel/drivers/hid \
                  kernel/drivers/net/ethernet kernel/net \
                  kernel/fs kernel/lib kernel/crypto; do
        src="/lib/modules/${KVER}/${moddir}"
        if [ -e "$src" ]; then
            dest="${ROOTFS}/lib/modules/${KVER}/${moddir}"
            mkdir -p "$(dirname "$dest")"
            cp -a "$src" "$dest" 2>/dev/null || true
        fi
    done
    cp -a "/lib/modules/${KVER}/modules."* "${ROOTFS}/lib/modules/${KVER}/" 2>/dev/null || true
    # Decompress .ko.zst/.ko.gz (busybox modprobe can't handle compressed)
    find "${ROOTFS}/lib/modules" -name '*.ko.zst' -exec zstd -d --rm {} \; 2>/dev/null || true
    find "${ROOTFS}/lib/modules" -name '*.ko.gz' -exec gzip -d {} \; 2>/dev/null || true
    # Regenerate modules.dep for our subset
    depmod -b "${ROOTFS}" "${KVER}" 2>/dev/null || true
fi

# kmod (if available, better than busybox modprobe)
if [ -f /sbin/modprobe ]; then
    cp -a /sbin/modprobe "${ROOTFS}/sbin/" 2>/dev/null || true
fi
if [ -f /bin/kmod ]; then
    cp -a /bin/kmod "${ROOTFS}/bin/" 2>/dev/null || true
fi
for lib in /usr/lib/libkmod.so* /lib/libkmod.so* \
           /usr/lib/libzstd.so* /lib/libzstd.so* \
           /usr/lib/liblzma.so* /lib/liblzma.so* \
           /usr/lib/libcrypto.so* /lib/libcrypto.so*; do
    for f in $lib; do
        [ -e "$f" ] || continue
        dest="${ROOTFS}${f}"
        mkdir -p "$(dirname "$dest")"
        cp -a "$f" "$dest" 2>/dev/null || true
    done
done

# === PID 1 init script ===
if [ "$MODE" = "online" ]; then
    cp /build/ttyai-init.sh "${ROOTFS}/init"
    cp /build/ttyai-interactive.sh "${ROOTFS}/init-interactive"
else
    cp /build/ttyai-init-offline.sh "${ROOTFS}/init"
    cp /build/ttyai-interactive-offline.sh "${ROOTFS}/init-interactive" 2>/dev/null || true
fi
chmod +x "${ROOTFS}/init"
[ -f "${ROOTFS}/init-interactive" ] && chmod +x "${ROOTFS}/init-interactive"

# === Verify ===
echo "=== ttyai rootfs (${MODE}) ==="
if [ "$MODE" = "online" ]; then
    for bin in node npm; do
        path=$(find "${ROOTFS}" -name "$bin" -type f -o -name "$bin" -type l | head -1)
        if [ -n "$path" ]; then
            echo "  OK: ${path#${ROOTFS}}"
        else
            echo "  MISSING: $bin"
        fi
    done
    echo "  AI CLIs: installed at boot time"
else
    for bin in node opencode ollama; do
        path=$(find "${ROOTFS}" -name "$bin" -type f -o -name "$bin" -type l | head -1)
        if [ -n "$path" ]; then
            echo "  OK: ${path#${ROOTFS}}"
        else
            echo "  MISSING: $bin"
        fi
    done
fi

# === Create initramfs ===
echo "Creating initramfs..."
cd "${ROOTFS}"
find . | cpio -o -H newc 2>/dev/null | gzip > /iso/boot/initramfs
SIZE=$(du -sh /iso/boot/initramfs | cut -f1)
echo "  initramfs: ${SIZE}"
echo "Done."
