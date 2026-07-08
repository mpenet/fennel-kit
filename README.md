# fennel-kit

LLMs writing Fennel code repeatedly break delimiter balance — a misplaced paren triggers a fix attempt that introduces another, and so on. fennel-kit breaks that loop by automatically repairing delimiters on every write.

Two tools:

- **`fennel-paren-repair-hook`** — Claude Code hook: repairs `.fnl` files transparently on every Write/Edit
- **`fennel-paren-repair`** — standalone CLI: repair files in place or pipe code through it

Both use [parinfer-rust](https://github.com/eraserhd/parinfer-rust) when available, falling back to a bundled pure-Fennel indent-mode implementation (`lib/parinfer.fnl`) with no extra dependencies.

## Requirements

- `fennel` — required at install time to compile scripts to Lua; not needed at runtime
- `lua` — required at runtime (scripts are compiled to `#!/usr/bin/env lua` by `make install`)
- [parinfer-rust](https://github.com/eraserhd/parinfer-rust) — optional but recommended
- `fnlfmt` — optional formatter, enabled via `--fnlfmt` flag; bundled and built from source by `make install`

## Installation

```sh
git clone https://github.com/mpenet/fennel-kit
cd fennel-kit
make install         # → ~/.local/bin, lib → ~/.local/lib/fennel-kit
make install-hook    # hook only
make install-repair  # repair CLI only
```

---

## `fennel-paren-repair-hook`

Hooks into Claude Code's Write and Edit tool calls to repair Fennel delimiters before/after every file operation. No manual intervention needed.

- **PreToolUse/Write** — intercepts content before it hits disk, returns corrected content to Claude
- **PostToolUse/Edit** — repairs the file on disk after each edit

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse":  [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "fennel-paren-repair-hook --fnlfmt"}]}],
    "PostToolUse": [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "fennel-paren-repair-hook --fnlfmt"}]}]
  }
}
```

Drop `--fnlfmt` if you don't have `fnlfmt` installed or don't want formatting after repair.

| Variable             | Default         | Description                  |
|----------------------|-----------------|------------------------------|
| `PARINFER_RUST_PATH` | `parinfer-rust` | Path to parinfer-rust binary |

---

## `fennel-paren-repair`

Repair files in place or use as a filter. Works with any LLM that has shell access.

```sh
# Fix files in place
fennel-paren-repair foo.fnl bar.fnl

# Fix and run fnlfmt after
fennel-paren-repair --fnlfmt foo.fnl bar.fnl

# Fix stdin → stdout
echo "(fn add [x y] (+ x y)" | fennel-paren-repair

# Pipe a heredoc
fennel-paren-repair <<'EOF'
(fn broken [x
  (+ x 1))
EOF
```

| Variable             | Default         | Description                  |
|----------------------|-----------------|------------------------------|
| `PARINFER_RUST_PATH` | `parinfer-rust` | Path to parinfer-rust binary |

---

## Docker

Useful for extracting a parinfer-rust binary without a local Rust toolchain:

```sh
docker build -t fennel-kit .
docker run --rm fennel-kit cat /usr/local/bin/parinfer-rust > /usr/local/bin/parinfer-rust
chmod +x /usr/local/bin/parinfer-rust
```

## Credits

Heavily inspired by [clojure-mcp-light](https://github.com/bhauman/clojure-mcp-light) by Bruce Hauman, which pioneered the same hook-based paren repair approach for Clojure.

## License

Copyright © 2026 Max Penet
Distributed under the Mozilla Public License Version 2.0
