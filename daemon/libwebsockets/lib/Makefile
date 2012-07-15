CC=gcc
CFLAGS=-Wall -g -rdynamic -DLWS_NO_FORK
RM=rm -f
OBJS=libwebsockets.o sha-1.o parsers.o md5.o handshake.o extension.o base64-decode.o client-handshake.o extension-deflate-stream.o extension-x-google-mux.o

all: $(OBJS) 

clean: 
	$(RM) $(OBJS)

libwebsockets.o: libwebsockets.c libwebsockets.h
	$(CC) $(INCLUDES) $(CFLAGS) -c -o libwebsockets.o libwebsockets.c

sha-1.o: sha-1.c
	$(CC) $(INCLUDES) $(CFLAGS) -c -o sha-1.o sha-1.c

parsers.o: parsers.c
	$(CC) $(INCLUDES) $(CFLAGS) -c -o parsers.o parsers.c

md5.o: md5.c
	$(CC) $(INCLUDES) $(CFLAGS) -c -o md5.o md5.c

handshake.o: handshake.c
	$(CC) $(INCLUDES) $(CFLAGS) -c -o handshake.o handshake.c

extension.o: extension.c
	$(CC) $(INCLUDES) $(CFLAGS) -c -o extension.o extension.c

base64-decode.o: base64-decode.c
	$(CC) $(INCLUDES) $(CFLAGS) -c -o base64-decode.o base64-decode.c

client-handshake.o: client-handshake.c
	$(CC) $(INCLUDES) $(CFLAGS) -c -o client-handshake.o client-handshake.c

extension-deflate-stream.o: extension-deflate-stream.c extension-deflate-stream.h private-libwebsockets.h
	$(CC) $(INCLUDES) $(CFLAGS) -c -o extension-deflate-stream.o extension-deflate-stream.c

extension-x-google-mux.o: extension-x-google-mux.c extension-x-google-mux.h private-libwebsockets.h
	$(CC) $(INCLUDES) $(CFLAGS) -c -o extension-x-google-mux.o extension-x-google-mux.c

