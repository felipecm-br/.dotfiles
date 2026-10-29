# agent-sudo: human-approved privileged commands for agents

Sandboxed agents (ai-jail) cannot type a sudo password. `agent-sudo` ([source](../../utils/.local/bin/agent-sudo))
opens a tmux popup on your client instead:

```
agent-sudo [-r REASON] [--no-sudo] -- CMD [ARGS...]
```

1. The popup follows the standard modal layout of [close-window.sh](../../tmux/.config/tmux/close-window.sh) (reactive layer: alert-yellow border and lock badge, Omarchy theme colors via `theme-helper.sh`, gradient frame, rounded border, 80 cols). Footer: `y approve │ n / Esc deny`, no brackets; after the run: `exit N │ Enter close`. It shows the exact argv, working directory and a reason; shells/interpreters get a red warning.
2. Nothing runs until you press `y`. Any other key denies (exit 126).
3. sudo prompts for the password inside the popup's own pty. The agent never sees it.
4. The agent receives the last 60 lines of output (`AGENT_SUDO_TAIL`) and the exit code.

Exit codes: command's own, `126` denied, `125` no tmux client, `124` timeout (`AGENT_SUDO_TIMEOUT`, default 300 s).

## Security notes

- argv is stored NUL-delimited and exec'd directly: no shell interpolation.
- Requests are logged to `~/.local/state/agent-sudo/log` (approved/denied/exit).
- sudo's default `timestamp_type=tty` ties the cached credential to the popup tty, so the agent's own `sudo` gains nothing.
- The popup runs under the tmux server, **outside the jail**. Only approve commands you understand.
- Do **not** expose the tmux socket to the jail to make this work: socket access means `send-keys`/`capture-pane` on every pane. See [ai-jail and the tmux socket](#ai-jail-and-the-tmux-socket).

Test: `tests/agent_sudo.test.sh`. No tmux keybinding is involved, so key telemetry is unaffected.

## ai-jail and the tmux socket

Verified on this machine: inside `ai-jail` (run from a neutral directory) `/tmp` is a fresh tmpfs, so
`/tmp/tmux-<uid>/default` is absent, `$TMUX` is empty and `~/.local/bin/agent-sudo` is not visible.
**The default is already correct: keep the socket blocked.** Consequence: `agent-sudo` works for agents
running unjailed (or in a pane outside the jail), but not from inside the jail.

For jailed agents there is a narrow bridge instead of the socket:

```
jailed agent ──▶ agent-sudo (client, ro-mapped) ──HTTP──▶ 127.0.0.1:49375 (forward_ports)
                                                              │
                                              agent-sudod (host, systemd user unit)
                                                              │
                                        agent-sudo ──▶ tmux popup ──▶ you press y + type password
```

- [`agent-sudod`](../../utils/.local/bin/agent-sudod) listens on `127.0.0.1:49375` (`AGENT_SUDO_PORT`). Its only endpoint is
  `POST /run` with `{argv, cwd, reason}`; it validates the shape, serves one request at a time (HTTP 429 when
  busy) and always goes through the approval popup. It has no way to touch tmux on the agent's behalf.
- Unit: `utils/.config/systemd/user/agent-sudod.service`; enable with `systemctl --user enable --now agent-sudod`.
- Jail wiring lives in the global `~/.ai-jail` (`zsh-plugins/.ai-jail`): `forward_ports = [49374, 49375]` and
  `ro_maps = ["/home/fecavmi/.local/bin/agent-sudo"]`. Inside the jail call `~/.local/bin/agent-sudo` by full path;
  without a tmux socket it automatically uses the bridge.
- Caveats: any process on host loopback can reach port 49375, but the worst it can do is open an approval popup
  you can deny. Prompts that arrive unexpectedly: press `n`. Ask the agent for the reason if unclear.
- Verified end to end from inside `ai-jail` (request reached the popup; unapproved popup returns 126).
