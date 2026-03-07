# ttyai

AIコーディングエージェントだけがインターフェースの Linux ディストリビューション。

シェルなし。デスクトップなし。逃げ場なし。

## 概要

```
電源ON → GRUB → Claude Code → 準備完了
```

Claude Code が PID 1 として動作する。シェルは存在しない。クラッシュした場合は自動で再起動する。シャットダウンするには AI に `poweroff` を実行してもらう。

内部は標準的な Linux — Alpine Linux + カーネル 6.12 LTS。AI はコマンド実行、ファイル編集、git 管理、パッケージ導入ができる。

## はじめかた

### ダウンロード

[Releases](https://github.com/ogio3/ttyai/releases)

| ファイル | アーキテクチャ | 状態 |
|------|-------------|--------|
| `ttyai-arm64.iso` | ARM64 | UTM (Apple Silicon) でテスト済み |
| `ttyai-x86_64.iso` | x86_64 | ビルド成功、未テスト |

ライブ ISO — ディスクへの書き込みなし。インターネット接続必須（Claude Code は初回起動時にインストール）。

### UTM (Apple Silicon)

1. 新規 VM 作成: **Virtualize** → **Linux** → `ttyai-arm64.iso` を CD ドライブとして接続
2. Display を **virtio-ramfb**、GPU Acceleration **OFF** に設定
3. VM を起動し、npm install が完了するまで待つ（約2分）
4. Claude Code が認証を求める

### Docker

```bash
docker run -it -e ANTHROPIC_API_KEY=sk-... ttyai/claude
```

### その他の環境

ISO は EFI ブート対応の x86_64 / ARM64 マシンで動作するはず。VirtualBox、VMware、実機で試した方は[結果を共有してください](https://github.com/ogio3/ttyai/issues)。

## 認証

Claude Code は2つの方法で認証できる:

- **Claude Pro/Max サブスクリプション**（OAuth）— おそらく動作するが、まだ十分に確認できていない。試した方は[報告してもらえると助かります](https://github.com/ogio3/ttyai/issues)。
- **API key** — `ttyai.key=` カーネルパラメータで設定可能（下記参照）。

両方のパスを確認でき次第、このセクションを更新する予定。どちらかで動作した方は、ぜひレポートをお願いします。

### ペーストの問題

UTM の Display ウィンドウはクリップボードペースト（Cmd+V）に対応していない。これはフレームバッファコンソールの[既知の制限](https://github.com/utmapp/UTM/issues/7045)。

Claude Code が OAuth URL を表示した場合、コピーできない。回避策:

1. URL が表示された UTM ウィンドウの**スクリーンショット**を撮る
2. OCR ツール（ChatGPT に画像を送る等）で URL を書き起こす
3. 書き起こした URL をブラウザで開いて認証を完了する

OAuth を省略するには、API key を事前設定する:

```
# UTM: VM Settings → QEMU → Boot Arguments
ttyai.key=sk-ant-api03-xxxxx
```

より良い解決策をご存知であれば [issue を開いてください](https://github.com/ogio3/ttyai/issues)。

## アーキテクチャ

| コンポーネント | 詳細 |
|-----------|--------|
| ベース | Alpine Linux 3.21 |
| カーネル | 6.12 LTS (ARM64 / x86_64) |
| Init | カスタムシェルスクリプト（約60行） |
| ランタイム | Node.js + npm |
| AI エージェント | Claude Code（起動時にインストール） |
| Init システム | なし（systemd なし、udev なし） |
| デスクトップ | なし |

## 現在の状態

| コンポーネント | 状態 |
|-----------|--------|
| ARM64 ISO (UTM) | ✅ テスト済み |
| x86_64 ISO | 🔨 未テスト |
| Docker 版 | ✅ テスト済み |
| Offline 版 | 🧪 実験的 |

## Offline 版

[OpenCode](https://github.com/anomalyco/opencode) + [Ollama](https://ollama.com) + qwen2.5-coder:1.5b モデルを同梱した実験的ビルド。インターネット・API key 不要。RAM 4GB 以上が必要。

```bash
./build-iso.sh offline arm64
```

この版は未テスト。コントリビューション歓迎。

## ビルドとテスト

```bash
git clone https://github.com/ogio3/ttyai.git && cd ttyai

# ISO
./build-iso.sh online arm64    # ARM64
./build-iso.sh online x86_64   # x86_64
./build-iso.sh offline arm64   # Offline 版

# Docker
./build.sh

# テスト（34項目の自動チェック）
./test-rootfs.sh
```

## Contributing

コントリビューション歓迎。詳細は [CONTRIBUTING.md](./CONTRIBUTING.md) を参照。

特に協力が必要な分野:

- **x86_64 テスト** — VirtualBox、VMware、実機でのブートレポート
- **AI エージェント追加** — Codex CLI、Aider、Gemini CLI 等
- **クリップボード問題の解決** — フレームバッファコンソールでのペースト改善
- **GPU パススルー** — Offline Ollama 版向け
- **ISO サイズ削減** — 現在 87MB

## FAQ

**シャットダウン方法は？** AI に `poweroff` を実行してもらう。

**シェルにアクセスできる？** できない。仕様。

**テキストをペーストできる？** VM の画面には直接できない。API key には `ttyai.key=` カーネルパラメータを使うか、起動後に SSH 接続する。

## ライセンス

[MIT](./LICENSE)

---

[@ogio3](https://github.com/ogio3) / [English](./README.md) / [Contributing](./CONTRIBUTING.md)
