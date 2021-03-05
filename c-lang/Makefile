LIBS = libtoml.a
HFILES = toml.h
EXEC = confshelf
CC := cc
LDFLAGS = $(shell pkg-config --libs libgit2)
CFLAGS = -std=c99 -Wall -Wextra -g3 $(shell pkg-config --cflags libgit2)

confshelf: confshelf.c $(LIBS)

*.o: $(HFILES)

libtoml.a: toml.o
	ar -rcs $@ $^

.PHONY: clean

clean:
	rm -f *.o $(LIBS) $(EXEC)
