NAME     := arabellity

SRC_DIR  := src
BUILD    := build
BIN      := $(BUILD)/$(NAME)

ASM      := nasm
ASMFLAGS := -f elf64 -g -F dwarf -I$(SRC_DIR)/ -DAPP_NAME='"$(NAME)"'
LD       := ld
RUSTC    := rustc

SRCS     := $(wildcard $(SRC_DIR)/*.asm)
INCS     := $(wildcard $(SRC_DIR)/*.inc)
OBJS     := $(patsubst $(SRC_DIR)/%.asm,$(BUILD)/%.o,$(SRCS))

.PHONY: all run clean debug font

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

clean:
	rm -rf $(BUILD)
