#!/bin/bash
# Simulated ttyai demo for asciinema recording
# Usage: asciinema rec --command ./demo/simulate.sh demo.cast

type_text() {
  local text="$1"
  local delay="${2:-0.04}"
  for ((i=0; i<${#text}; i++)); do
    printf '%s' "${text:$i:1}"
    sleep "$delay"
  done
}

type_line() {
  type_text "$1" "${2:-0.04}"
  sleep "${3:-0.3}"
  printf '\n'
}

pause() { sleep "${1:-1}"; }

clear
# Scene 1: Docker run command
printf '\033[1;32m$\033[0m '
type_line "docker run -it -e ANTHROPIC_API_KEY=sk-ant-... ttyai/claude" 0.05
pause 1.5

# Scene 2: Claude Code startup
printf '\n'
printf '\033[1;37m ╭─────────────────────────────────────────╮\033[0m\n'
printf '\033[1;37m │\033[0m                                           \033[1;37m│\033[0m\n'
printf '\033[1;37m │\033[0m   \033[1;33mttyai\033[0m                                  \033[1;37m│\033[0m\n'
printf '\033[1;37m │\033[0m   No shell. No desktop. No escape.        \033[1;37m│\033[0m\n'
printf '\033[1;37m │\033[0m                                           \033[1;37m│\033[0m\n'
printf '\033[1;37m ╰─────────────────────────────────────────╯\033[0m\n'
pause 1

printf '\n\033[0;90mStarting Claude Code...\033[0m\n'
pause 1.5
printf '\033[0;90mAuthenticated via API key.\033[0m\n'
pause 0.8
printf '\n'

# Scene 3: Claude Code prompt
printf '\033[1;34m>\033[0m '
type_line "Create a simple HTTP server in Python that responds with \"Hello from ttyai\"" 0.03
pause 1

# Scene 4: Claude Code response
printf '\n\033[0;90mI'\''ll create a simple HTTP server for you.\033[0m\n\n'
pause 0.8

printf '\033[1;37mserver.py\033[0m\n'
pause 0.3

# Code output with syntax highlighting
code_lines=(
  '\033[1;34mfrom\033[0m http.server \033[1;34mimport\033[0m HTTPServer, BaseHTTPRequestHandler'
  ''
  '\033[1;34mclass\033[0m \033[1;33mHandler\033[0m(BaseHTTPRequestHandler):'
  '    \033[1;34mdef\033[0m \033[1;32mdo_GET\033[0m(self):'
  '        self.send_response(\033[1;35m200\033[0m)'
  '        self.send_header(\033[0;32m"Content-Type"\033[0m, \033[0;32m"text/plain"\033[0m)'
  '        self.end_headers()'
  '        self.wfile.write(\033[0;32mb"Hello from ttyai"\033[0m)'
  ''
  'HTTPServer((\033[0;32m""\033[0m, \033[1;35m8080\033[0m), Handler).serve_forever()'
)

for line in "${code_lines[@]}"; do
  printf '  %b\n' "$line"
  sleep 0.15
done

pause 0.8
printf '\n\033[0;90mCreated server.py\033[0m\n'
pause 0.5

# Scene 5: Run it
printf '\n\033[1;34m>\033[0m '
type_line "Run it" 0.05
pause 0.8

printf '\n\033[0;90m$ python3 server.py &\033[0m\n'
pause 0.5
printf '\033[0;90m$ curl localhost:8080\033[0m\n'
pause 0.8
printf '\033[1;37mHello from ttyai\033[0m\n'
pause 0.5

printf '\n\033[0;90mServer is running on port 8080.\033[0m\n'
pause 2
