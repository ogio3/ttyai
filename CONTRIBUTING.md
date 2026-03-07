# Contributing

Thank you for your interest. Contributions of any kind are welcome.

## Getting Started

```bash
git clone https://github.com/ogio3/ttyai.git && cd ttyai
./test-rootfs.sh        # Run 34 automated checks
./build-iso.sh online arm64  # Build an ISO
```

## Areas Where Help Is Needed

### Testing

- **x86_64 boot reports** — VirtualBox, VMware, Hyper-V, or bare metal. Does it boot? Does the display work? Does keyboard input work?
- **Different hypervisors** — Parallels, GNOME Boxes, libvirt/KVM
- **Real hardware** — Any EFI-capable machine

### New AI Agents

The architecture supports adding more agents. Each agent needs:

1. An init script (see `iso/ttyai-init.sh` as reference — ~60 lines)
2. An interactive script (see `iso/ttyai-interactive.sh`)
3. A GRUB menu entry
4. A Dockerfile for the Docker edition

Agents that would be great to add:
- [Codex CLI](https://github.com/openai/codex) (OpenAI)
- [Aider](https://github.com/paul-gauthier/aider)
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) (Google)
- [Continue](https://github.com/continuedev/continue)

### Known Issues

- **Clipboard paste** — UTM/QEMU framebuffer console doesn't support Cmd+V. Looking for any solution that works without requiring a full GUI.
- **ISO size** — 87MB is reasonable but could be smaller.
- **Offline edition** — Built but untested. Uses OpenCode + Ollama.

## How to Submit

1. Fork the repository
2. Create a branch for your change
3. Run `./test-rootfs.sh` to verify nothing is broken
4. Open a pull request with a description of what you changed and why

## Code Style

- Shell scripts: POSIX sh compatible (BusyBox)
- Keep init scripts minimal — every line runs as PID 1
- No systemd, no udev, no mdev — modules are loaded explicitly

## Project Structure

```
ttyai/
├── iso/
│   ├── ttyai-init.sh              # PID 1: mount, modprobe, network, getty
│   ├── ttyai-interactive.sh       # Banner, npm install, launch Claude Code
│   ├── ttyai-init-offline.sh      # PID 1 (offline): mount, modprobe, ollama, getty
│   ├── ttyai-interactive-offline.sh # Banner, ollama wait, launch OpenCode
│   ├── build-rootfs.sh            # Rootfs builder (shared online/offline)
│   ├── grub.cfg                   # GRUB config (online)
│   └── grub-offline.cfg           # GRUB config (offline)
├── Dockerfile.iso-online          # ISO builder (online)
├── Dockerfile.iso-offline         # ISO builder (offline)
├── Dockerfile.claude              # Docker edition
├── build-iso.sh                   # Build ISOs
├── build.sh                       # Build Docker edition
├── test-rootfs.sh                 # 34 automated tests
└── docs/
    └── display-debug-log.md       # UTM display debugging notes
```

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](./LICENSE).
