SHELL := /usr/bin/env bash

.PHONY: lint install

lint:
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck is required"; \
		exit 1; \
	fi
	shellcheck -x spawn.sh lib/spawn-core.sh lib/spawn-commands.sh lib/spawn-completion.sh install.sh

install:
	./install.sh
