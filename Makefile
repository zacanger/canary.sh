EXEC=canary.sh

PREFIX?= /usr/local
BINDIR?= $(PREFIX)/bin

install: canary.sh
	install -Dm 755 $(EXEC) $(DESTDIR)$(BINDIR)/$(EXEC)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(EXEC)

test:
	shellcheck --shell=bash canary.sh scripts/changelog.sh scripts/release.sh

.PHONY: test uninstall
