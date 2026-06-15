PREFIX ?= /usr
DESTDIR ?=

# `make` assembles the single-file ./pfetch from the modules in src/.
all: build

# Glue src/*.sh back into the runnable, self-contained ./pfetch script.
build:
	@./build.sh

# Run the behavioral test suite against a freshly built script.
test: build
	@sh tests/run.sh

# Static analysis. We lint the *assembled* pfetch (the real program) plus the
# standalone helper scripts. The src/*.sh files are intentionally fragments
# (no shebang, shared state across modules), so linting them individually
# would only produce false positives; they are covered via the bundle.
check: build
	@shellcheck pfetch build.sh tests/run.sh

# Install rebuilds first so the installed copy always matches src/.
install: build
	@install -Dm755 pfetch $(DESTDIR)$(PREFIX)/bin/pfetch

uninstall:
	@rm -f $(DESTDIR)$(PREFIX)/bin/pfetch

.PHONY: all build test check install uninstall
