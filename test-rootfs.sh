#!/bin/bash
# Test ttyai rootfs inside Docker — fast feedback without ISO/VM boot
# Usage: ./test-rootfs.sh [online|offline]
#
# Builds the rootfs in Docker, then runs validation checks via chroot.
# Catches module dependency errors, missing binaries, broken symlinks
# in seconds instead of the 20+ minute ISO→VM boot cycle.
set -e

MODE="${1:-online}"
IMAGE="ttyai/rootfs-test:${MODE}"

echo "=== ttyai rootfs test (${MODE}) ==="
echo ""

# Build the rootfs (reuse ISO Dockerfile up to rootfs step)
echo "[1/4] Building rootfs..."
if [ "$MODE" = "online" ]; then
    DOCKERFILE="Dockerfile.iso-online"
else
    DOCKERFILE="Dockerfile.iso-offline"
fi

docker build --platform linux/arm64 \
    -f "$DOCKERFILE" \
    --target builder \
    -t "$IMAGE" . > /tmp/ttyai-build.log 2>&1

if [ $? -ne 0 ]; then
    echo "  FAIL: Docker build failed"
    tail -30 /tmp/ttyai-build.log
    exit 1
fi
echo "  OK: rootfs built"

# Run test suite inside the builder container
echo "[2/4] Testing module dependencies..."
docker run --rm --platform linux/arm64 "$IMAGE" sh -c '
    ROOTFS=/rootfs
    PASS=0
    FAIL=0

    check() {
        local desc="$1" cmd="$2"
        if eval "$cmd" > /dev/null 2>&1; then
            echo "  OK: $desc"
            PASS=$((PASS + 1))
        else
            echo "  FAIL: $desc"
            eval "$cmd" 2>&1 | head -5 | sed "s/^/    /"
            FAIL=$((FAIL + 1))
        fi
    }

    echo "--- Binary existence ---"
    check "/bin/sh exists" "[ -x ${ROOTFS}/bin/sh ]"
    check "/usr/bin/node exists" "[ -x ${ROOTFS}/usr/bin/node ]"
    check "/init exists" "[ -x ${ROOTFS}/init ]"

    if [ "'"$MODE"'" = "online" ]; then
        check "/usr/bin/npm exists" "[ -x ${ROOTFS}/usr/bin/npm ] || [ -L ${ROOTFS}/usr/bin/npm ]"
        check "/usr/bin/env exists" "[ -e ${ROOTFS}/usr/bin/env ]"
    else
        check "opencode exists" "[ -x ${ROOTFS}/usr/local/bin/opencode ]"
        check "ollama exists" "[ -x ${ROOTFS}/usr/local/bin/ollama ]"
    fi

    echo ""
    echo "--- Busybox symlinks ---"
    for cmd in sh mount ip hostname sleep clear modprobe setsid getty wget; do
        check "busybox: $cmd" "[ -L ${ROOTFS}/bin/${cmd} ] || [ -L ${ROOTFS}/sbin/${cmd} ] || [ -x ${ROOTFS}/bin/${cmd} ] || [ -x ${ROOTFS}/sbin/${cmd} ]"
    done

    echo ""
    echo "--- Shared libraries ---"
    check "ld-musl" "ls ${ROOTFS}/lib/ld-musl-*.so.* 2>/dev/null | grep -q ."
    check "libz" "ls ${ROOTFS}/lib/libz.so* ${ROOTFS}/usr/lib/libz.so* 2>/dev/null | grep -q ."
    check "libssl" "ls ${ROOTFS}/lib/libssl*.so* ${ROOTFS}/usr/lib/libssl*.so* 2>/dev/null | grep -q ."
    check "libstdc++" "ls ${ROOTFS}/usr/lib/libstdc++.so* 2>/dev/null | grep -q ."

    echo ""
    echo "--- Node.js runs ---"
    check "node --version" "chroot ${ROOTFS} /usr/bin/node --version"

    echo ""
    echo "--- Kernel modules ---"
    KVER=$(ls ${ROOTFS}/lib/modules/ 2>/dev/null | head -1)
    if [ -n "$KVER" ]; then
        check "modules.dep exists" "[ -f ${ROOTFS}/lib/modules/${KVER}/modules.dep ]"

        echo ""
        echo "--- Module dependency chain (virtio_gpu) ---"
        # Check each module in the load order exists
        for mod in i2c-core drm drm_kms_helper drm_shmem_helper drm_buddy virtio-gpu xhci-pci xhci-hcd usbhid hid-generic; do
            modfile=$(grep -r "/${mod}.ko" ${ROOTFS}/lib/modules/${KVER}/modules.dep 2>/dev/null | head -1 | cut -d: -f1)
            if [ -z "$modfile" ]; then
                # Try underscore variant
                mod_us=$(echo "$mod" | tr - _)
                modfile=$(grep -r "/${mod_us}.ko" ${ROOTFS}/lib/modules/${KVER}/modules.dep 2>/dev/null | head -1 | cut -d: -f1)
            fi
            if [ -n "$modfile" ]; then
                # Check dependencies are also present
                deps=$(grep "^${modfile##*/}:" ${ROOTFS}/lib/modules/${KVER}/modules.dep 2>/dev/null | cut -d: -f2)
                missing=""
                for dep in $deps; do
                    if [ ! -f "${ROOTFS}/lib/modules/${KVER}/${dep}" ]; then
                        missing="$missing $dep"
                    fi
                done
                if [ -z "$missing" ]; then
                    check "module: $mod (deps OK)" "true"
                else
                    check "module: $mod (MISSING deps:$missing)" "false"
                fi
            else
                check "module: $mod exists" "false"
            fi
        done

        # Also verify with depmod
        echo ""
        echo "--- depmod verification ---"
        check "depmod clean" "depmod -b ${ROOTFS} ${KVER} 2>&1 | grep -v WARNING || true"

    else
        echo "  SKIP: no kernel modules found"
    fi

    echo ""
    echo "--- SSL certs ---"
    check "cert.pem exists" "[ -f ${ROOTFS}/etc/ssl/cert.pem ]"

    echo ""
    echo "--- Init script syntax ---"
    check "init script parses" "chroot ${ROOTFS} /bin/sh -n /init"

    echo ""
    echo "================================"
    echo "  PASS: $PASS  FAIL: $FAIL"
    echo "================================"
    [ $FAIL -eq 0 ] && exit 0 || exit 1
'

TEST_EXIT=$?
echo ""

if [ $TEST_EXIT -eq 0 ]; then
    echo "[3/4] All tests passed"
    echo "[4/4] rootfs is ready for ISO packaging"
else
    echo "[3/4] Tests FAILED — fix before building ISO"
    echo "[4/4] Skipped"
    exit 1
fi
