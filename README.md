# fennel-mcp

A structural editing MCP server for [Fennel](https://fennel-lang.org), built on [tree-sitter-fennel](https://github.com/alexmozaidze/tree-sitter-fennel) via [ltreesitter](https://github.com/euclidianAce/ltreesitter).

Instead of blind text replacement, tools locate S-expressions as real AST nodes and operate on their exact byte ranges. Broken parentheses, partial matches, and whitespace corruption are not possible — if the form isn't a valid node in the tree, the operation is refused.

Written in pure Fennel, runs on Lua 5.4, served over JSON-RPC stdio.

## Requirements

- Docker

## Installation

### 1. Build the image

```sh
git clone https://github.com/mpenet/fennel-mcp
cd fennel-mcp
docker build -t fennel-mcp .
```

### 2. Install the wrapper script

```sh
sudo cp bin/fennel-mcp /usr/local/bin/fennel-mcp
```

The wrapper mounts `$HOME` into the container at the same path, so all files under your home directory are accessible using their native host paths.

### 3. Add to Claude Code

```sh
claude mcp add fennel-mcp -- fennel-mcp
```

## Tools

### `fennel_view_ast`

Show the tree-sitter AST of a Fennel file as indented text. Use this before editing to understand structure and verify form text exactly.

| Parameter | Type   | Required | Description                                      |
|-----------|--------|----------|--------------------------------------------------|
| `file`    | string | yes      | Path to the `.fnl` file                          |
| `sexp`    | string | no       | Exact source text of a form to scope the view to |

**Example output:**
```
program  (fn add [x y]↵  (+ x y))↵↵(fn main []↵  (print …
  fn_form  (fn add [x y]↵  (+ x y))
    symbol  fn
    symbol  add
    sequence_arguments  [x y]
      symbol_binding  x
      symbol_binding  y
    list  (+ x y)
      symbol  +
      symbol  x
      symbol  y
  fn_form  (fn main []↵  (print (add 1 2)))
    ...
```

---

### `fennel_edit`

Replace an S-expression with new content.

| Parameter  | Type   | Required | Description                              |
|------------|--------|----------|------------------------------------------|
| `file`     | string | yes      | Path to the `.fnl` file                  |
| `old_sexp` | string | yes      | Exact source text of the form to replace |
| `new_sexp` | string | yes      | Replacement text                         |

**Example:** rename `add` to `sum` and update its body:
```
old_sexp: "(fn add [x y]\n  (+ x y))"
new_sexp: "(fn sum [x y]\n  (+ x y))"
```

---

### `fennel_delete`

Delete an S-expression from a file. Collapses any blank lines left behind.

| Parameter | Type   | Required | Description                             |
|-----------|--------|----------|-----------------------------------------|
| `file`    | string | yes      | Path to the `.fnl` file                 |
| `sexp`    | string | yes      | Exact source text of the form to delete |

---

### `fennel_insert`

Insert a new form before or after an existing anchor form.

| Parameter  | Type   | Required | Description                         |
|------------|--------|----------|-------------------------------------|
| `file`     | string | yes      | Path to the `.fnl` file             |
| `anchor`   | string | yes      | Exact source text of the anchor form |
| `form`     | string | yes      | New form to insert                  |
| `position` | string | yes      | `"before"` or `"after"` the anchor  |

---

### `fennel_append`

Append a new top-level form at the end of a file.

| Parameter | Type   | Required | Description             |
|-----------|--------|----------|-------------------------|
| `file`    | string | yes      | Path to the `.fnl` file |
| `form`    | string | yes      | Form to append          |

## Workflow tips

- **Always run `fennel_view_ast` first.** It gives you the exact node text including whitespace and newlines, which you need to match `old_sexp` / `anchor` precisely.
- Pass native host paths (e.g. `/Users/you/project/src/foo.fnl`). The container sees them at the same path via the `$HOME` mount.
- The server validates that every target is a real AST node. It will refuse matches on partial text or misaligned boundaries.

## Architecture

```
server.fnl        — JSON-RPC 2.0 over stdio, MCP protocol, tool dispatch
fennel_edit.fnl   — all editing operations (parse, find, mutate)
Dockerfile        — Alpine 3.21, Lua 5.4, ltreesitter, tree-sitter-fennel grammar
```

The grammar `.so` is compiled from source during the Docker build. ltreesitter bundles the tree-sitter runtime, so no system-level tree-sitter installation is needed at runtime.

## License

Copyright © 2026 Max Penet
Distributed under the Mozilla Public License Version 2.0
