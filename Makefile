PREFIX ?= /usr

.PHONY: all install uninstall test

all:
	@echo RUN \'make install\' to install pfetch

install:
	@install -Dm755 pfetch $(DESTDIR)$(PREFIX)/bin/pfetch

uninstall:
	@rm -f $(DESTDIR)$(PREFIX)/bin/pfetch

test:
	@shellcheck pfetch
	@sh test/pfetch-test.sh
