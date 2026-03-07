# ttyai Display Debug Log — UTM ARM64

> 2026-03-07 セッション記録。長期戦のための詳細ログ。

## 目標

UTM (Apple Silicon ARM64) で ttyai ISO をブートし、Display ウィンドウに init スクリプトの出力（バナー、プロンプト）を表示し、**キーボード入力を受け付ける**。

## 環境

- **Host**: macOS Darwin 24.6.0, Apple Silicon (ARM64)
- **VM**: UTM (QEMU 10.0 ARM Virtual Machine, virt-10.0)
- **UTM Display設定**: `virtio-ramfb` (GPU Acceleration OFF)
- **Guest OS**: Alpine Linux 3.21, カーネル 6.12.76-0-lts (ARM64)
- **Init**: カスタム `/init` シェルスクリプト (PID 1), BusyBox, systemd/udev なし

## カーネル設定（関連部分）

```
CONFIG_SYSFB=y                    # 組み込み
CONFIG_SYSFB_SIMPLEFB=y           # 組み込み
CONFIG_DRM=m                      # モジュール
CONFIG_DRM_SIMPLEDRM=m            # モジュール
CONFIG_DRM_VIRTIO_GPU=m           # モジュール
CONFIG_DRM_FBDEV_EMULATION=y      # 組み込み
CONFIG_FRAMEBUFFER_CONSOLE=y      # 組み込み（fbcon）
CONFIG_VT=y                       # 組み込み
CONFIG_VT_CONSOLE=y               # 組み込み
CONFIG_FB=y                       # 組み込み
CONFIG_FB_EFI=y                   # 組み込み
CONFIG_VIRTIO_MMIO=m              # モジュール
```

## 試行履歴

### 試行1: オリジナル構成（セッション開始前）
- **GRUB**: `console=ttyAMA0,115200 console=ttyS0,115200 console=tty0`
- **Init modprobe**: virtio系 + DRM基本（drm, drm_kms_helper のみ）
- **結果**: DRM Unknown symbol エラー多数（drm_gem_fb_destroy 等100個以上）
- **原因**: drm_shmem_helper, drm_buddy, i2c_core が rootfs に不在
- **修正**: build-rootfs.sh で DRM ツリー全体 + i2c をコピー

### 試行2: DRM依存解決後
- **GRUB**: 同上
- **Init modprobe**: + i2c_core, drm_shmem_helper, drm_buddy 追加
- **結果**: DRMエラー解消。`ACPI: bus type drm_connector registered` まで出るが画面進まず
- **原因**: virtio-gpu PCI デバイス (1af4:1050) が PCI バスに不在
- **誤診断**: UTMの Display 設定が virtio-ramfb でないと想定 → 実際は virtio-ramfb だった

### 試行3: console パラメータ変更 + gfxpayload
- **GRUB**: `console=tty0 earlycon` + `set gfxpayload=keep`
- **Init modprobe**: simpledrm + virtio_gpu 両方
- **結果**:
  - virtio-gpu PCI (1af4:1050) が**出現**（試行2では不在だった）
  - simpledrm → fb0, virtio_gpu → fb1
  - fbcon は fb0 (simpledrm) に張り付き
  - UTM Display は fb1 (virtio_gpu) を見ている → 「Display output is not active」
- **重要発見**: console= パラメータを変えたら PCI デバイス構成が変わった（理由不明）
- **原因**: simpledrm が先に fb0 を取り、virtio_gpu が fb1 になる。UTM Display は virtio_gpu のみ表示

### 試行4: simpledrm 除去
- **GRUB**: 同上 (console=tty0 earlycon, gfxpayload=keep)
- **Init modprobe**: simpledrm を削除、virtio_gpu のみ
- **結果**:
  - virtio_gpu が fb0 になった
  - `Console: switching to colour frame buffer device 160x50`
  - **UTM Display にバナーとプロンプトが表示された！**
  - **しかしキーボード入力が効かない**
- **原因**: PID 1 が controlling terminal を持っていない。`read` コマンドが stdin を読めない

### 試行5: setsid + cttyhack
- **変更**: init を2ファイルに分割（/init + /init-interactive）
- **Init**: `exec setsid cttyhack /bin/sh /init-interactive`
- **結果**: PF_PACKET 行で「フリーズ」（画面が進まない）
- **原因**: Alpine の busybox に `cttyhack` アプレットが含まれていない可能性大。exec 先が存在しないコマンドのため PID 1 が異常終了

### 試行6: setsid + /dev/tty0 リダイレクト
- **変更**: `exec setsid /bin/sh -c 'exec /bin/sh /init-interactive </dev/tty0 >/dev/tty0 2>&1'`
- **結果**:
  - **UTM Display にバナーとプロンプトが表示された**
  - **キーボード入力が効かない**（試行4と同じ症状）
- **原因**: `/dev/tty0` を開いても controlling terminal にならない？ または UTM の keyboard input が virtio-gpu ディスプレイと連動していない？

### 試行7: USB HID + getty（最終解決）
- **変更**:
  1. `modprobe xhci_pci xhci_hcd usbhid hid_generic evdev` 追加
  2. `kernel/drivers/usb` を rootfs にコピー
  3. `setsid /sbin/getty -n -l /init-interactive 38400 tty1 linux` で ctty 確立
  4. `stty sane` でターミナル初期化
  5. `/etc/hosts` に `127.0.0.1 localhost` 追加
- **結果**: **Display出力 + キーボード入力 両方動作！**
- Claude Code v2.1.71 が起動し、API key 入力を受け付けた

## 最終状態

| 項目 | 状態 |
|------|------|
| DRMモジュール依存 | **解決済み** |
| virtio-gpu PCI検出 | **解決済み** (1af4:1050) |
| virtio_gpu fb0 | **解決済み** |
| fbcon → virtio_gpu | **解決済み** |
| UTM Display 画面出力 | **解決済み** |
| キーボード入力 | **解決済み** — USB HID + getty |
| Claude Code 起動 | **解決済み** — npm install → claude 起動 |

## 未解決: キーボード入力問題の分析

### 何が分かっているか
1. UTM Display ウィンドウにバナーと「Version (latest):」プロンプトが表示されている
2. キーボードを打っても画面に文字が出ない（`read` に入力が届いていない）
3. `setsid` + `/dev/tty0` リダイレクトでは不十分

### 何が分かっていないか
1. UTM の keyboard input はどのデバイスに送られるのか（/dev/tty0? /dev/console? /dev/input/*?）
2. PID 1 の子プロセスで controlling terminal を正しく設定する方法（BusyBox Alpine環境）
3. `cttyhack` が Alpine busybox に含まれているかの確認
4. virtio keyboard/input デバイスのカーネルモジュールが必要か

### 根本原因（Light Research 3社合意 — 2026-03-07 15:36確定）

**2層の問題が同時に存在:**

1. **下層（ドライバ層）**: USB HID ドライバが未ロード
   - `virtio-gpu` / `virtio-ramfb` は**映像専用**。入力デバイスは含まない
   - UTM/QEMU ARM64 はデフォルトで USB keyboard (`qemu-xhci` + `usb-kbd`) をエミュレート
   - udev/mdev 不在のため、これらのドライバが自動ロードされない
   - 必要なモジュールチェーン: `xhci-pci` → `xhci-hcd` → `usbhid` → `hid-generic` → `evdev`
   - これらを **一度も modprobe していなかった**

2. **上層（TTY層）**: Controlling Terminal の設定不備
   - `exec >/dev/tty0 </dev/tty0` だけでは ctty にならない（TIOCSCTTY 必要）
   - Alpine BusyBox の `cttyhack` は**無効化されている**（確定）
   - 正しい方法: `getty` コマンドに ctty 設定を任せる

### 確定した解決策

```sh
# 1. 入力デバイスドライバをロード
modprobe xhci-pci usbhid hid-generic evdev

# 2. getty に ctty 設定を任せる
exec /sbin/getty -n -l /path/to/interactive-script 38400 tty1 linux
```

### デバッグ確認手順（次セッション冒頭で実行）
1. `cat /proc/bus/input/devices` — 何も出なければモジュール未ロード確定
2. `ls -l /dev/input/` — `eventX` がなければ VT 入力不可能
3. `modprobe xhci-pci usbhid hid-generic evdev` — 強制ロード
4. `cat /dev/input/event0` — キーを叩いて文字化け出力があればドライバ層OK

### 情報源
- QEMU USB: https://www.qemu.org/docs/master/system/devices/usb.html
- QEMU Virtio: https://www.qemu.org/docs/master/system/devices/virtio.html
- Alpine Custom Initramfs: https://wiki.alpinelinux.org/wiki/Custom_initramfs
- BusyBox inittab: https://git.busybox.net/busybox/tree/examples/inittab

## ファイル構成（現在）

```
hell-linux/
  Dockerfile.iso-online          # COPY ttyai-interactive.sh 追加済み
  Dockerfile.iso-offline
  build-iso.sh
  test-rootfs.sh                 # Docker chroot テスト (29/29 PASS)
  iso/
    grub.cfg                     # console=tty0 earlycon, gfxpayload=keep
    grub-offline.cfg             # 同上
    build-rootfs.sh              # cttyhack 追加済み, init-interactive コピー追加
    ttyai-init.sh                # PID 1, setsid + /dev/tty0 → /init-interactive
    ttyai-init-offline.sh        # offline版（simpledrm除去済み、ctty未修正）
    ttyai-interactive.sh         # 対話部分（バナー、read、npm install、CLI起動）
```

## セッション中に学んだこと

1. **console= パラメータが PCI デバイス構成に影響する**: ttyAMA0/ttyS0 を含む古いパラメータではvirtio-gpu PCI デバイスが出現せず、earlycon + tty0 のみにしたら出現した（原因不明、QEMU/UTM の挙動？）
2. **simpledrm vs virtio_gpu の fb0 競合**: simpledrm が先に EFI GOP を取ると fb0 になり、virtio_gpu が fb1 に。UTM Display は virtio_gpu しか見ない
3. **gfxpayload=keep は必須**: GRUB の EFI GOP モードをカーネルに渡すために必要
4. **BusyBox init の ctty 問題**: PID 1 は controlling terminal を持たない。子プロセスでの ctty 確立が必要だが、Alpine busybox での正しい方法が未確定
5. **Docker chroot でテストできる範囲**: ファイル存在・モジュール依存まで。display/input/ctty はVM必須
