EXEC=canary.sh

PREFIX?= /usr/local
BINDIR?= $(PREFIX)/bin

install:
	install -Dm 755 $(EXEC) $(DESTDIR)$(BINDIR)/$(EXEC)

test:
	shellcheck --shell=bash canary.sh

.PHONY: install test
