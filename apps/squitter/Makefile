MIX = mix
CFLAGS = -g -O3 -pedantic -Wall

ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS += -I$(ERLANG_PATH)
MODES_PATH = .
CFLAGS += -I$(MODES_PATH)/src

ifneq ($(OS),Windows_NT)
	CFLAGS += -fPIC

	ifeq ($(shell uname),Darwin)
		LDFLAGS += -dynamiclib -undefined dynamic_lookup
	endif
endif

.PHONY: all modes clean

all: priv priv/modes.so

priv:
	mkdir -p priv

priv/modes.so: src/modes.c
	$(CC) $(CFLAGS) -shared $(LDFLAGS) -o $@ src/modes.c

clean:
	$(RM) priv/modes.so
