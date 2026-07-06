IMAGE   = fennel-mcp
WRAPPER = /usr/local/bin/fennel-mcp

.PHONY: all build install setup

all: install

build:
	docker build -t $(IMAGE) .

install: build
	sudo cp bin/fennel-mcp $(WRAPPER)
	sudo chmod +x $(WRAPPER)

setup-claude: install
	claude mcp add fennel-mcp -- fennel-mcp
