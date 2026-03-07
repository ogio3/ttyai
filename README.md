# ttyai

A Linux distribution where the only interface is an AI coding agent.

No shell. No desktop. No escape.

<p align="center">
  <img src="demo/ttyai-demo.gif" alt="ttyai demo" width="600">
</p>

## Overview

```
Power on → GRUB → Claude Code → ready
```

Claude Code runs as PID 1. There is no shell underneath. If it crashes, it restarts automatically. The only way to shut down is to ask the AI to run `poweroff`.

Under the hood, it's a standard Linux system — Alpine Linux with kernel 6.12 LTS. The AI can run commands, edit files, manage git, and install packages.

## Getting Started

### Download

[Releases](https://github.com/ogio3/ttyai/releases)

| File | Architecture | Status |
|------|-------------|--------|
| `ttyai-arm64.iso` | ARM64 | Tested on UTM (Apple Silicon) |
| `ttyai-x86_64.iso` | x86_64 | Builds successfully, untested |

Live ISOs — they don't write to disk. Internet connection required (Claude Code is installed at first boot).

### UTM (Apple Silicon)

1. Create a new VM: **Virtualize** → **Linux** → attach `ttyai-arm64.iso` as a CD drive
2. Set Display to **virtio-ramfb** with GPU Acceleration **OFF**
3. Boot the VM and wait for the npm install to complete (~2 minutes)
4. Claude Code will prompt you to authenticate

### Docker

```bash
docker run -it -e ANTHROPIC_API_KEY=sk-... ttyai/claude
```

### Other environments

The ISO should work on any x86_64 or ARM64 machine with EFI boot. If you try it on VirtualBox, VMware, or real hardware, please [share your results](https://github.com/ogio3/ttyai/issues).

## Authentication

Claude Code supports two ways to authenticate:

- **OAuth** (Claude Pro / Max / Team subscription) — Claude Code displays a URL on screen. Open it in your host browser to log in. Uses your subscription.
- **API key** — Set `ANTHROPIC_API_KEY` as an environment variable. Skips OAuth entirely. Uses [API credit](https://console.anthropic.com/) (separate from your subscription).

### Using an API key

**Docker:**

```bash
docker run -it -e ANTHROPIC_API_KEY=sk-ant-... ttyai/claude
```

**ISO (kernel parameter):**

```
# UTM: VM Settings → QEMU → Boot Arguments
ttyai.key=sk-ant-api03-xxxxx
```

The kernel command line is readable by any process inside the VM (`/proc/cmdline`). This is fine for a live ISO that doesn't write to disk.

### Note on UTM paste

UTM's framebuffer console does not support Cmd+V ([known limitation](https://github.com/utmapp/UTM/issues/7045)). If you use OAuth, screenshot the URL and open it on your host machine.

## Architecture

| Component | Detail |
|-----------|--------|
| Base | Alpine Linux 3.21 |
| Kernel | 6.12 LTS (ARM64 / x86_64) |
| Init | Custom shell script (~60 lines) |
| Runtime | Node.js + npm |
| AI Agent | Claude Code (installed at boot) |
| Init system | None (no systemd, no udev) |
| Desktop | None |

## Current Status

| Component | Status |
|-----------|--------|
| ARM64 ISO on UTM | ✅ Tested |
| x86_64 ISO | 🔨 Untested |
| Docker edition | ✅ Tested |
| Offline edition | 🧪 Experimental |

## Offline Edition

An experimental offline build using [OpenCode](https://github.com/anomalyco/opencode) + [Ollama](https://ollama.com) with a bundled qwen2.5-coder:1.5b model. No internet or API key required. Needs 4GB+ RAM.

```bash
./build-iso.sh offline arm64
```

This edition is untested. Contributions are welcome.

## Build and Test

```bash
git clone https://github.com/ogio3/ttyai.git && cd ttyai

# ISO
./build-iso.sh online arm64    # ARM64
./build-iso.sh online x86_64   # x86_64
./build-iso.sh offline arm64   # Offline edition

# Docker
./build.sh

# Tests (34 automated checks)
./test-rootfs.sh
```

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) for details.

Areas where help would be particularly valuable:

- **x86_64 testing** — boot reports from VirtualBox, VMware, or real hardware
- **Additional AI agents** — Codex CLI, Aider, Gemini CLI, etc.
- **Clipboard solution** — a better way to handle paste in framebuffer consoles
- **GPU passthrough** — for the offline Ollama edition
- **ISO size reduction** — currently 87MB

## FAQ

**How do I shut down?** Ask the AI to run `poweroff`.

**Can I access a shell?** No. That is by design.

**Can I paste text into the VM?** Not directly. Use the `ttyai.key=` kernel parameter for API keys, or SSH into the VM after it boots.

## License

[MIT](./LICENSE)

---

[@ogio3](https://github.com/ogio3) / [日本語](./README.ja.md) / [Contributing](./CONTRIBUTING.md)
