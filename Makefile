NAME     := arabellity
VERSION  := 0.1.0

SRC_DIR  := src
BUILD    := build
BIN      := $(BUILD)/$(NAME)

ASM      := nasm
ASMFLAGS := -f elf64 -g -F dwarf -I$(SRC_DIR)/ -DAPP_NAME='"$(NAME)"'
LD       := ld
RUSTC    := rustc
STRIP    := strip

SRCS     := $(wildcard $(SRC_DIR)/*.asm)
INCS     := $(wildcard $(SRC_DIR)/*.inc)
OBJS     := $(patsubst $(SRC_DIR)/%.asm,$(BUILD)/%.o,$(SRCS))

PREFIX   ?= /usr/local
BINDIR   ?= $(PREFIX)/bin
DATADIR  ?= $(PREFIX)/share

.PHONY: all run clean debug font install uninstall dist test

all: $(BIN)

$(BIN): $(OBJS)
	$(LD) -o $@ $^

$(BUILD)/%.o: $(SRC_DIR)/%.asm $(INCS) | $(BUILD)
	$(ASM) $(ASMFLAGS) -o $@ $<

$(BUILD):
	mkdir -p $@

font: | $(BUILD)
	$(RUSTC) -O scripts/gen_font.rs -lfreetype -o $(BUILD)/gen_font
	./$(BUILD)/gen_font

run: $(BIN)
	./$(BIN)

debug: $(BIN)
	gdb ./$(BIN)

install: $(BIN)
	install -Dm755 $(BIN) $(DESTDIR)$(BINDIR)/$(NAME)
	install -Dm644 assets/arabellity.desktop $(DESTDIR)$(DATADIR)/applications/$(NAME).desktop
	@if [ -f assets/icons/arabellity.svg ]; then \
		install -Dm644 assets/icons/arabellity.svg $(DESTDIR)$(DATADIR)/icons/hicolor/scalable/apps/$(NAME).svg; \
	fi
	@for s in 16 32 48 64 128 256; do \
		if [ -f assets/icons/arabellity-$${s}x$${s}.png ]; then \
			install -Dm644 assets/icons/arabellity-$${s}x$${s}.png $(DESTDIR)$(DATADIR)/icons/hicolor/$${s}x$${s}/apps/$(NAME).png; \
		fi \
	done
	install -Dm644 arabellity.conf $(DESTDIR)$(DATADIR)/$(NAME)/arabellity.conf.example

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(NAME)
	rm -f $(DESTDIR)$(DATADIR)/applications/$(NAME).desktop
	rm -f $(DESTDIR)$(DATADIR)/icons/hicolor/scalable/apps/$(NAME).svg
	@for s in 16 32 48 64 128 256; do \
		rm -f $(DESTDIR)$(DATADIR)/icons/hicolor/$${s}x$${s}/apps/$(NAME).png; \
	done
	rm -rf $(DESTDIR)$(DATADIR)/$(NAME)

dist: $(BIN) | $(BUILD)
	mkdir -p $(BUILD)/$(NAME)-$(VERSION)
	cp $(BIN) $(BUILD)/$(NAME)-$(VERSION)/$(NAME)
	$(STRIP) -s $(BUILD)/$(NAME)-$(VERSION)/$(NAME)
	cp assets/arabellity.desktop $(BUILD)/$(NAME)-$(VERSION)/
	@if [ -d assets/icons ]; then \
		mkdir -p $(BUILD)/$(NAME)-$(VERSION)/icons; \
		cp assets/icons/* $(BUILD)/$(NAME)-$(VERSION)/icons/ 2>/dev/null || true; \
	fi
	cp arabellity.conf $(BUILD)/$(NAME)-$(VERSION)/
	cp README.md $(BUILD)/$(NAME)-$(VERSION)/
	@if [ -f README.ru.md ]; then cp README.ru.md $(BUILD)/$(NAME)-$(VERSION)/; fi
	@if [ -f LICENSE ]; then cp LICENSE $(BUILD)/$(NAME)-$(VERSION)/; fi
	tar -czf $(BUILD)/$(NAME)-$(VERSION)-linux-x86_64.tar.gz -C $(BUILD) $(NAME)-$(VERSION)
	@echo "Distribution archive created: $(BUILD)/$(NAME)-$(VERSION)-linux-x86_64.tar.gz"

test: $(BIN)
	@echo "1. Checking comments in ASM source files..."
	@python3 -c "import glob, sys; errs=[(f,i,l) for f in glob.glob('src/*.asm')+glob.glob('src/*.inc') for i,l in enumerate(open(f),1) if l.strip().startswith(';')]; sys.exit(1 if errs else 0)" || (echo "FAILED: Comments found in assembly files!" && exit 1)
	@echo "   OK: 0 comments found."
	@echo "2. Verifying static binary (zero dynamic dependencies)..."
	@LC_ALL=C readelf -d $(BIN) 2>&1 | grep -q 'There is no dynamic section' || (echo "FAILED: Binary has dynamic section!" && exit 1)
	@echo "   OK: Pure static ELF binary (zero libc/ld.so dependencies)."
	@echo "3. Binary executable check..."
	@test -x $(BIN) || (echo "FAILED: Binary not executable" && exit 1)
	@echo "   OK: $(BIN) is ready."
	@echo "All tests passed successfully!"

clean:
	rm -rf $(BUILD)
