REPAIR      = /usr/local/bin/fennel-paren-repair
REPAIR_HOOK = /usr/local/bin/fennel-paren-repair-hook
LIB_DIR     = /usr/local/lib/fennel-kit

.PHONY: all install install-hook install-repair test

all: install

install: install-repair install-hook

install-lib:
	sudo mkdir -p $(LIB_DIR)
	sudo cp lib/parinfer.fnl $(LIB_DIR)/parinfer.fnl
	sudo cp lib/json.lua $(LIB_DIR)/json.lua

install-repair: install-lib
	sudo cp bin/fennel-paren-repair $(REPAIR)
	sudo chmod +x $(REPAIR)

install-hook: install-lib
	sudo cp bin/fennel-paren-repair-hook $(REPAIR_HOOK)
	sudo chmod +x $(REPAIR_HOOK)

test:
	fennel test/parinfer_test.fnl
