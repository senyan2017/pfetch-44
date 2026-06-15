PREFIX ?= /usr

all:
	@echo RUN \'make install\' to install pfetch

install:
	@install -Dm755 pfetch $(DESTDIR)$(PREFIX)/bin/pfetch

uninstall:
	@rm -f $(DESTDIR)$(PREFIX)/bin/pfetch

test:
	@sh tests/minimal-env.sh

.PHONY: all install uninstall test
