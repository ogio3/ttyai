#!/bin/bash
# Build ttyai Docker edition
set -e

echo "=== Building ttyai — Claude Code (Docker) ==="
docker build -f Dockerfile.claude -t ttyai/claude:latest .

echo ""
echo "=== Done ==="
echo "Run with:"
echo "  docker run -it -e ANTHROPIC_API_KEY=sk-... ttyai/claude"
