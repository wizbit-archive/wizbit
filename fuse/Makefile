PREFIX ?= /usr
CC = gcc
CFLAGS=-g -O0
LDFLAGS=-luuid

all: fstore-test dir-test

fstore-test : fstore.o fstore-test.o

dir-test : dir.o fstore.o dir-test.o

clean:
	rm -rf *.o *~ *.file *.data

distclean: clean
	rm -rf fstore-test dir-test
