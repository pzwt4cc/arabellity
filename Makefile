# TODO: придумать название (заглушка, меняется только здесь)
NAME     := noname

SRC_DIR  := src
BUILD    := build
BIN      := $(BUILD)/$(NAME)

ASM      := nasm
ASMFLAGS := -f elf64 -g -F dwarf -I$(SRC_DIR)/ -DAPP_NAME='"$(NAME)"'
LD       := ld

SRCS     := $(wildcard $(SRC_DIR)/*.asm)
OBJS     := $(patsubst $(SRC_DIR)/%.asm,$(BUILD)/%.o,$(SRCS))

.PHONY: all run clean debug

all: $(BIN)

$(BIN): $(OBJS)
	$(LD) -o $@ $^

$(BUILD)/%.o: $(SRC_DIR)/%.asm | $(BUILD)
	$(ASM) $(ASMFLAGS) -o $@ $<

$(BUILD):
	mkdir -p $@

run: $(BIN)
	./$(BIN)

debug: $(BIN)
	gdb ./$(BIN)

clean:
	rm -rf $(BUILD)
