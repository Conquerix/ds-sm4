SRC	:= $(wildcard *.c)
OBJ	:= $(patsubst %.c,%.o,$(SRC))
EXEC	:= ctr_enc

ifdef ARM
CC := arm-linux-gnueabihf-gcc
endif

ifdef TIMER_OFF
CFLAGS += -DTIMER_OFF=$(TIMER_OFF)
endif

.PHONY: help all
.DEFAULT_GOAL := help

define HELP_message
usage: make [GOAL] [VARIABLE=VALUE...]

GOALS:
    help          print this help message (default goal)
    ctr_enc       compile ctr_enc
    all           same as ctr_enc
    clean         delete all generated files

VARIABLES:
    ARM           if set to non-empty string cross-compile for ARM target
    TIMER_OFF     set to timer word offset in registers area if timer exists

Examples:

    to compile for ARM target, with a timer at address 0x40000020 (word offset 0x20/4 = 8):
      make ctr_enc ARM=1 TIMER_OFF=8
    or:
      make all ARM=1 TIMER_OFF=8

    to compile for host computer
      make ctr_enc
    or:
      make all

    to clean-up:
      make clean
endef
export HELP_message

help:
	@printf '%s\n' "$$HELP_message"

all: $(EXEC)

$(OBJ): utils.h
$(EXEC): %: %.o utils.o

clean:
	rm -f $(OBJ) $(EXEC)
