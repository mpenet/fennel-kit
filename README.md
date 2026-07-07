# fennel-kit

CLI tools for LLM coding assistants working with [Fennel](https://fennel-lang.org).

Solves the **"Paren Edit Death Loop"** — where an LLM repeatedly fails to fix mismatched delimiters in Fennel code. Three tools:

- [`fennel-paren-repair-hook`](#fennel-paren-repair-hook) — Auto-fix delimiters via Claude Code hooks
- [`fennel-paren-repair`](#fennel-paren-repair) — On-demand delimiter fix (any LLM with shell access)
- [`fennel-eval`](#fennel-eval) — Evaluate Fennel code in a persistent REPL process

Inspired by [clojure-mcp-light](https://github.com/bhauman/clojure-mcp-light).

## Requirements

- [parinfer-rust](https://github.com/eraserhd/parinfer-rust) — preferred delimiter repair engine (optional)
- `fennel` — required for `fennel-eval` / `fennel-eval-server`; also used as fallback repair engine when parinfer-rust is absent
- `fnlfmt` (optional) — formatter, enabled via `FENNEL_KIT_FNLFMT=1`

When parinfer-rust is not installed, repair falls back to a pure-Fennel indent-mode implementation bundled in `lib/parinfer.fnl`. It inserts missing closers and removes misplaced ones. The only known limitation: multi-line string literals (rare in Fennel) may confuse the tokenizer.

## Installation

```sh
git clone https://github.com/mpenet/fennel-kit
cd fennel-kit
make install         # all tools → /usr/local/bin, lib → /usr/local/lib/fennel-kit
make install-hook    # hook only
make install-repair  # repair CLI only
make install-eval    # eval tools only
```

---

## `fennel-paren-repair-hook`

Claude Code hook that automatically repairs Fennel delimiter errors on every Write/Edit operation.

### How it works

- **PreToolUse/Write**: intercepts the file content before it's written, repairs delimiters, passes corrected content back to Claude
- **PostToolUse/Edit**: repairs the file on disk after an Edit

### Configuration

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse":  [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "fennel-paren-repair-hook"}]}],
    "PostToolUse": [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "fennel-paren-repair-hook"}]}]
  }
}
```

### Environment

| Variable             | Default         | Description                                    |
|----------------------|-----------------|------------------------------------------------|
| `PARINFER_RUST_PATH` | `parinfer-rust` | Path to parinfer-rust binary                   |
| `FENNEL_KIT_FNLFMT`  | `0`             | Set to `1` to run `fnlfmt --fix` after repair  |

---

## `fennel-paren-repair`

Standalone CLI for on-demand repair. Useful with Gemini CLI, Codex, or any LLM with shell access.

### Usage

```sh
# Fix files in place
fennel-paren-repair foo.fnl bar.fnl

# Fix stdin, output to stdout
echo "(fn add [x y] (+ x y)" | fennel-paren-repair

# Heredoc
fennel-paren-repair <<'EOF'
(fn broken [x
  (+ x 1))
EOF
```

### Environment

| Variable             | Default         | Description                                    |
|----------------------|-----------------|------------------------------------------------|
| `PARINFER_RUST_PATH` | `parinfer-rust` | Path to parinfer-rust binary                   |
| `FENNEL_KIT_FNLFMT`  | `0`             | Set to `1` to run `fnlfmt --fix` after repair  |

---

## `fennel-eval`

Persistent-state Fennel REPL for LLM use. Code is repaired before eval (parinfer-rust preferred, Fennel fallback otherwise).

### Usage

```sh
# Start server in current project directory
fennel-eval-server

# Evaluate code
fennel-eval "(+ 1 2)"
# => 3

# Global bindings persist across calls
fennel-eval "(global x 42)"
fennel-eval "x"
# => 42

# Require modules (resolved via project's package.path)
fennel-eval "(local m (require :mymodule)) (m.my-fn 1 2)"

# Show running server info
fennel-eval --discover

# Stop server
fennel-eval-server --stop
# or: fennel-eval --stop
```

### Notes

- `local` bindings don't persist across eval calls (Lua chunk scoping). Use `global` for state that must persist between calls.
- One server per project directory, discovered via `.fennel-repl` in the current directory. Add `.fennel-repl` to your `.gitignore`.
- Serial access only — one eval at a time, which matches LLM usage patterns.

### Environment

| Variable             | Default         | Description                          |
|----------------------|-----------------|--------------------------------------|
| `FENNEL_REPL_INFO`   | `.fennel-repl`  | Path to server discovery file        |
| `FENNEL_CMD`         | `fennel`        | Fennel binary to use                 |
| `PARINFER_RUST_PATH` | `parinfer-rust` | Path to parinfer-rust binary         |

### Telling the LLM about `fennel-eval`

Add to `~/.claude/CLAUDE.md` or the project's `CLAUDE.md`:

```markdown
## Fennel REPL

The command `fennel-eval` is available for evaluating Fennel code.

Start the server first: `fennel-eval-server`

Evaluate code: `fennel-eval "(+ 1 2)"`

Use `global` for bindings that should persist across eval calls:
`fennel-eval "(global x 42)"`

The REPL session persists — state is maintained between evaluations.
```

---

## Docker

The Docker image bundles parinfer-rust and all scripts. Useful for extracting the parinfer-rust binary without a local Rust toolchain:

```sh
docker build -t fennel-kit .
docker run --rm fennel-kit cat /usr/local/bin/parinfer-rust > /usr/local/bin/parinfer-rust
chmod +x /usr/local/bin/parinfer-rust
```

## License

Copyright © 2026 Max Penet
Distributed under the Mozilla Public License Version 2.0
