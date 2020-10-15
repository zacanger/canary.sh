EXEC=canary.sh

PREFIX?= /usr/local
BINDIR?= $(PREFIX)/bin

all: $(EXEC)

install:
	install -Dm 755 $(EXEC) $(DESTDIR)$(BINDIR)/$(EXEC)

test:
	shellcheck --shell=bash canary.sh
