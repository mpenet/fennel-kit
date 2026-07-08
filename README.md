# fennel-kit

LLMs writing Fennel code repeatedly break delimiter balance — a misplaced paren triggers a fix attempt that introduces another, and so on. fennel-kit breaks that loop by automatically repairing delimiters on every write.

Three tools:

- **`fennel-paren-repair-hook`** — Claude Code hook: repairs `.fnl` files transparently on every Write/Edit
- **`fennel-paren-repair`** — standalone CLI: repair files in place or pipe code through it
- **`fennel-eval`** / **`fennel-eval-server`** — persistent Fennel REPL over TCP: evaluate code with state preserved across calls

The repair tools use [parinfer-rust](https://github.com/eraserhd/parinfer-rust) when available, falling back to a bundled pure-Fennel indent-mode implementation (`lib/parinfer.fnl`) with no extra dependencies.

## Requirements

- `fennel` — required at install time (compiles scripts to Lua) and at runtime for `fennel-eval-server`
- `lua` — required at runtime (scripts compiled to `#!/usr/bin/env lua` by `make install`)
- `luasocket` — required for `fennel-eval` and `fennel-eval-server` (`luarocks install luasocket`)
- [parinfer-rust](https://github.com/eraserhd/parinfer-rust#installing) — optional but recommended
- `fnlfmt` — optional formatter, enabled via `--fnlfmt` flag; bundled and built from source by `make install`

## Installation

```sh
git clone https://github.com/mpenet/fennel-kit
cd fennel-kit
make install         # all tools → ~/.local/bin, lib → ~/.local/lib/fennel-kit
make install-hook    # hook only
make install-repair  # repair CLI only
make install-eval    # fennel-eval + fennel-eval-server only
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

## `fennel-eval` / `fennel-eval-server`

A persistent Fennel REPL server and CLI client. State (locals, requires, defs) persists across invocations via `fennel.repl`. Requires `luasocket` and Lua 5.4+.

Implements the [fennel-proto-repl protocol](https://gitlab.com/andreyorst/fennel-proto-repl-protocol), so editors with proto-repl support (fennel-mode, Conjure) can connect directly to the server port. One client is served at a time.

### Installation

```sh
make install-eval   # installs fennel-eval and fennel-eval-server to ~/.local/bin
```

### Starting the server

Start once per project, in the background, from the project root:

```sh
fennel-eval-server &
# fennel-eval-server listening on 127.0.0.1:PORT
# Port file: /your/project/.fennel-repl
```

The port is written to `.fennel-repl` in the current directory. `fennel-eval` walks up the directory tree to find it automatically, so you can call it from any subdirectory of the project.

### Evaluating code

```sh
fennel-eval "(+ 1 2 3)"
# 6

fennel-eval "(local x 42)"
# nil

# State persists — x is still defined:
fennel-eval "x"
# 42

# stdin for multi-line:
fennel-eval <<'EOF'
(fn greet [name]
  (.. "hello " name))
(greet "world")
EOF
# #<function: ...>
# "hello world"
```

`stdout` output and return values are both captured and printed. Errors exit with code 1.

### Options

| `fennel-eval` option | Description |
|----------------------|-------------|
| `--port PORT` | Connect to specific port (default: reads `.fennel-repl`) |
| `--timeout MS` | Eval timeout in ms (default: 30000) |
| `--discover-ports` | Find running servers in current directory tree |

| `fennel-eval-server` option | Description |
|-----------------------------|-------------|
| `--port PORT` | Listen on specific port (default: random) |

### Using with Claude Code

Add the following to your project's `CLAUDE.md` (or `~/.claude/CLAUDE.md` globally):

````markdown
## Fennel REPL Evaluation

`fennel-eval` is available for evaluating Fennel code via a running `fennel-eval-server`.
State (locals, requires, defs) persists across calls.

**Evaluate code:**

```sh
fennel-eval "(+ 1 2)"
fennel-eval --timeout 10000 "(some-slow-operation)"
```

**Multi-line via stdin:**

```sh
fennel-eval <<'EOF'
(local result (some-fn arg1 arg2))
result
EOF
```

**Discover running servers:**

```sh
fennel-eval --discover-ports
```

Always use `fennel-eval` to test code after writing or editing Fennel files.
Use `:reload` when requiring modules to pick up changes.
````

Then start the server at the beginning of each Fennel session:

```sh
fennel-eval-server &
```

Claude will use `fennel-eval` via Bash to verify code as it writes it — catching errors before they accumulate.

---

## Credits

Heavily inspired by [clojure-mcp-light](https://github.com/bhauman/clojure-mcp-light) by Bruce Hauman, which pioneered the same hook-based paren repair approach for Clojure.

## License

Copyright © 2026 Max Penet
Distributed under the Mozilla Public License Version 2.0
