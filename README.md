# antigravity-harness

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Fedora-lightgrey.svg)](#install)
[![Shell](https://img.shields.io/badge/shell-bash%203.2%2B-4EAA25.svg?logo=gnubash&logoColor=white)](scripts/)
[![Antigravity](https://img.shields.io/badge/Antigravity-harness-4285F4.svg?logo=google&logoColor=white)](https://antigravity.google/docs)

My user-level config for [Google Antigravity](https://antigravity.google/docs): the IDE, the Antigravity app and the `agy` CLI. Global rules, hooks, plugins and MCP live in `~/.gemini/config/` and are shared by all three; `agy` also gets a statusline, permissions and settings. This repo *is* `~/.gemini`, tracked with an allowlist `.gitignore`, so sign-in tokens, conversations, browser profiles and installed plugins never enter git.

The sibling of [claude-harness](https://github.com/antialberteinstein/claude-harness), ported to Antigravity's customization system.

Supported: macOS and Fedora.

## What's inside

| Part | What it does |
| --- | --- |
| Plugins | [Superpowers](https://github.com/obra/superpowers), [Karpathy guidelines](https://github.com/multica-ai/andrej-karpathy-skills) and [kessie-skills](https://github.com/antialberteinstein/kessie-skills), installed from git by `agy-sync` |
| [ECC](https://github.com/affaan-m/ECC) (selected) | A local `ecc-selected` plugin with 17 skills and 13 reviewer/resolver agents, converted to Antigravity subagents. The full `ecc` plugin is disabled (not removed). ECC hooks are left out: they are written for Claude Code |
| `GEMINI.md` | Load the Karpathy guidelines before coding; run tests before calling a task done; use `gh`, `hf`, `kaggle`, `uv` instead of guessing; ask before adding CI that runs e2e tests. |
| Permissions (`agy`) | Auto mode in the terminal sandbox; `~/.ssh`, the Antigravity sign-in token and `~/.claude.json` denied; anything that pushes data out (`git push`, PRs, releases, uploads) asks first |
| Secret guard | A `PreToolUse` hook stops file tools from reading or editing `.env` and `.env.*` in any folder (`.env.example`, `.sample`, `.template` stay readable), in the IDE, app and `agy` |
| MCP | Context7 for up-to-date library docs, in the shared `mcp_config.json` |
| Statusline (`agy`) | Lualine-style: Vim or agent mode, git branch, directory, quota used, context bar, model |
| Notifications | `agy`: built-in bell and desktop notification. IDE and app: a `Stop` hook sends a system notification when the agent finishes |

### Where things go

| File in this repo | Read by | Notes |
| --- | --- | --- |
| `GEMINI.md` | IDE, app, `agy` | Global rules. The 24 KB per-file cap includes `@[..](..)` includes |
| `config/hooks.json` | IDE, app, `agy` | Shared lifecycle hooks: secret guard, finish notification |
| `config/skills/harness-check/`, `config/skills/setup-agy-project/` | IDE, app, `agy` | The `/harness-check` and `/setup-agy-project` skills |
| `agy-settings.json` | `setup.sh` | Merged into `~/.gemini/antigravity-cli/settings.json` (see below) |
| `statusline.sh` | `agy` | Custom status line |
| `scripts/setup.d/config.sh` | `setup.sh`, `agy-sync` | CLIs, MCP servers, plugins, commands to link |

`agy` writes its own `settings.json` (model, trusted workspaces, "always allow" rules), and trusted workspaces are private paths. So that file is not tracked. `setup.sh` merges `agy-settings.json` into it instead: objects are deep-merged with the harness winning, `permissions.allow/ask/deny` lists are unioned minus `REMOVE_PERMISSIONS`, and `@HOME@` becomes this machine's `$HOME`. The old file is backed up first.

## Install

Requirements: `git`, `jq` and the [Antigravity CLI](https://antigravity.google/docs/cli) (`agy`).

```bash
# 1. Clone anywhere
git clone https://github.com/antialberteinstein/antigravity-harness.git ~/antigravity-harness

# 2. Preview, then move the repo into ~/.gemini
bash ~/antigravity-harness/scripts/move.sh -n
bash ~/antigravity-harness/scripts/move.sh

# 3. Check dependencies, install the CLIs, log in, merge settings, link commands
bash ~/.gemini/scripts/setup.sh --install --login --add-path

# 4. Install the plugins and build ecc-selected
agy-sync
```

`move.sh` never overwrites silently: any existing file in `~/.gemini` that differs from the repo is moved to `~/.gemini/backups/harness-<timestamp>/` first. Everything else already in `~/.gemini` is left alone.

Run `bash ~/.gemini/scripts/setup.sh -n` at any time to see what setup would change without changing it.

## Usage

```bash
git -C ~/.gemini pull && bash ~/.gemini/scripts/setup.sh --only settings && agy-sync   # update
agy-sync -n                            # preview what agy-sync would install
agy-sync --update                      # reinstall the git plugins at their latest version
show chart.png                         # open an image or report (new Kitty window, or the default viewer)
bash ~/.gemini/scripts/setup.sh --list # list setup modules; run one with --only <name>
bash ~/.gemini/scripts/setup.d/test.sh # offline tests
```

Inside `agy` (or the IDE and app):

- `/harness-check`: run setup and `agy-sync` in preview mode, list MCP servers and the harness repo's git state, then report problems and offer fixes. It replaces kessie-skills' Claude-only `/harness-check`.
- `/setup-agy-project`: the Antigravity version of kessie-skills' `/setup-project`. It reads the project's manifests, proposes ECC skills and subagents, MCP servers and Antigravity marketplace plugins from [its catalog](config/skills/setup-agy-project/catalog.md), waits for your yes, then installs everything into one workspace plugin, `.agents/plugins/project-kit/`. Delete that folder to undo, or commit it to share with the team. It skips anything the global `ecc-selected` plugin already has.
- kessie-skills' `/proj`, `/issue-resolve`, `/pr-review` work as on Claude Code; `/setup-project` and `/add-preset` are Claude Code only.

If [claude-harness](https://github.com/antialberteinstein/claude-harness) already linked `show`, setup keeps that link: both harnesses ship the same script.

Optional environment variables:

| Variable | Effect |
| --- | --- |
| `AGY_SL_NERD=0` | Statusline without Nerd Font icons |
| `AGY_SL_THEME` | Statusline colors: `tokyonight` (default), `catppuccin`, `gruvbox` |
| `AGY_NOTIFY_CLI=1` | Let the `Stop` hook notify for `agy` sessions too |
| `AGY_NOTIFY_SOUND=0` | Mute notification sounds |
| `AGY_NOTIFY_LOG=1` | Log notifications to `~/.gemini/notify.log` |

Machine-specific overrides for setup and `agy-sync` go in `scripts/setup.d/config.local.sh` (ignored by git).

## Limits

- `agy` permission rules take absolute paths only: a relative rule such as `read_file(.env)` makes the terminal sandbox reject every command (`non-absolute file path`). That is why `.env` is guarded by a hook, and why `REMOVE_PERMISSIONS` in `config.sh` strips rules the harness no longer wants (the merge otherwise only adds).
- agy's terminal sandbox cannot read `~/.gemini`, so the harness skills run their scripts outside it (agy asks first). A slash command also reaches the agent without the skill's path, which is why these skills spell out `~/.gemini/...` paths.
- The secret guard covers file tools, not shell commands such as `cat .env`, the same as claude-harness's `Read` deny rules.
- Auto mode needs the terminal sandbox and is not offered on business or enterprise accounts.

## License

[MIT](LICENSE) © Nhat Nguyen. `ecc-selected` is built from [ECC](https://github.com/affaan-m/ECC) (MIT, Affaan Mustafa); its license is copied into the plugin.
