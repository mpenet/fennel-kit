REPAIR      = $(HOME)/.local/bin/fennel-paren-repair
REPAIR_HOOK = $(HOME)/.local/bin/fennel-paren-repair-hook
FNLFMT      = $(HOME)/.local/bin/fnlfmt
EVAL        = $(HOME)/.local/bin/fennel-eval
EVAL_SERVER = $(HOME)/.local/bin/fennel-eval-server
LIB_DIR     = $(HOME)/.local/lib/fennel-kit

.PHONY: all install install-hook install-repair install-fnlfmt install-eval dev test

all: install

install: install-repair install-hook install-fnlfmt install-eval

install-lib:
	mkdir -p $(LIB_DIR)
	fennel --compile lib/parinfer.fnl > $(LIB_DIR)/parinfer.lua
	cp lib/json.lua $(LIB_DIR)/json.lua
	cp lib/fnlfmt.fnl $(LIB_DIR)/fnlfmt.fnl
	cp lib/fnlfmt-cli.fnl $(LIB_DIR)/fnlfmt-cli.fnl

install-repair: install-lib
	mkdir -p $(HOME)/.local/bin
	printf '#!/usr/bin/env lua\n' > $(REPAIR)
	fennel --compile bin/fennel-paren-repair >> $(REPAIR)
	chmod +x $(REPAIR)

install-hook: install-lib
	mkdir -p $(HOME)/.local/bin
	printf '#!/usr/bin/env lua\n' > $(REPAIR_HOOK)
	fennel --compile bin/fennel-paren-repair-hook >> $(REPAIR_HOOK)
	chmod +x $(REPAIR_HOOK)

install-fnlfmt: install-lib
	mkdir -p $(HOME)/.local/bin
	printf '#!/usr/bin/env lua\n' > $(FNLFMT)
	cd $(LIB_DIR) && fennel --require-as-include --compile fnlfmt-cli.fnl >> $(FNLFMT)
	chmod +x $(FNLFMT)

install-eval: install-lib
	mkdir -p $(HOME)/.local/bin
	printf '#!/usr/bin/env lua\n' > $(EVAL)
	fennel --compile bin/fennel-eval >> $(EVAL)
	chmod +x $(EVAL)
	cp bin/fennel-eval-server $(EVAL_SERVER)
	chmod +x $(EVAL_SERVER)

dev:
	fennel --compile lib/parinfer.fnl > lib/parinfer.lua

test:
	fennel test/parinfer_test.fnl
