REPAIR      = $(HOME)/.local/bin/fennel-paren-repair
REPAIR_HOOK = $(HOME)/.local/bin/fennel-paren-repair-hook
FNLFMT      = $(HOME)/.local/bin/fnlfmt
LIB_DIR     = $(HOME)/.local/lib/fennel-kit

.PHONY: all install install-hook install-repair install-fnlfmt test

all: install

install: install-repair install-hook install-fnlfmt

install-lib:
	mkdir -p $(LIB_DIR)
	cp lib/parinfer.fnl $(LIB_DIR)/parinfer.fnl
	cp lib/json.lua $(LIB_DIR)/json.lua
	cp lib/fnlfmt.fnl $(LIB_DIR)/fnlfmt.fnl
	cp lib/fnlfmt-cli.fnl $(LIB_DIR)/fnlfmt-cli.fnl

install-repair: install-lib
	mkdir -p $(HOME)/.local/bin
	cp bin/fennel-paren-repair $(REPAIR)
	chmod +x $(REPAIR)

install-hook: install-lib
	mkdir -p $(HOME)/.local/bin
	cp bin/fennel-paren-repair-hook $(REPAIR_HOOK)
	chmod +x $(REPAIR_HOOK)

install-fnlfmt: install-lib
	mkdir -p $(HOME)/.local/bin
	printf '#!/usr/bin/env lua\n' > $(FNLFMT)
	cd $(LIB_DIR) && fennel --require-as-include --compile fnlfmt-cli.fnl >> $(FNLFMT)
	chmod +x $(FNLFMT)

test:
	fennel test/parinfer_test.fnl
