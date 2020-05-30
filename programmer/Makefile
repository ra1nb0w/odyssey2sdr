CC?=cc
CC_WIN?=i686-w64-mingw32-gcc

.DEFAULT_GOAL := programmer

.PHONY: programmer
programmer:
	$(CC) -std=c89 -o programmer main.c

.PHONY: win
win:
	$(CC_WIN) -std=c89 -o programmer.exe main.c -lws2_32

clean:
	rm programmer programmer.exe
