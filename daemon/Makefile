CC=gcc
CFLAGS=-Wall -g -rdynamic
LDFLAGS=-g -rdynamic -Wl -lpthread
INTERNALINCLUDES=-I./minissdpd -I./miniupnp -I./libwebsockets/lib
RM=rm -f
OBJS=ickDiscovery.o ickDiscoveryRegistry.o ickP2PComm.o ickSocketDaemon.o
MINIUPNPOBJS=miniupnp/connecthostport.o miniupnp/miniwget.o miniupnp/minixml.o miniupnp/receivedata.o
MINISSDPDOBJS=minissdpd/openssdpsocket.o minissdpd/upnputils.o
LIBWEBSOCKETSOBJS=libwebsockets/lib/libwebsockets.o libwebsockets/lib/sha-1.o libwebsockets/lib/parsers.o libwebsockets/lib/md5.o libwebsockets/lib/handshake.o libwebsockets/lib/extension.o libwebsockets/lib/base64-decode.o libwebsockets/lib/client-handshake.o libwebsockets/lib/extension-deflate-stream.o libwebsockets/lib/extension-x-google-mux.o
LIBS=-lz
all: $(OBJS) minissdpd/libminissdpd.a miniupnp/libminiupnp.a libwebsockets/lib/libwebsockets.a ickSocketDaemon
DEBUGFLAGS=

clean: 
	$(RM) $(OBJS)
	cd minissdpd;$(MAKE) $(MFLAGS) clean
	cd miniupnp;$(MAKE) $(MFLAGS) clean
	cd libwebsockets/lib;$(MAKE) $(MFLAGS) clean

ickDiscovery.o: ickDiscovery.c ickDiscovery.h
	$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o ickDiscovery.o ickDiscovery.c

ickDiscoveryRegistry.o: ickDiscoveryRegistry.c
	$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o ickDiscoveryRegistry.o ickDiscoveryRegistry.c

ickP2PComm.o: ickP2PComm.c
	$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o ickP2PComm.o ickP2PComm.c

ickSocketDaemon.o: ickSocketDaemon.c ickDiscovery.h
	$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o ickSocketDaemon.o ickSocketDaemon.c

minissdpd/libminissdpd.a: force_look
	cd minissdpd;$(MAKE) $(MFLAGS)

miniupnp/libminiupnp.a: force_look
	cd miniupnp;$(MAKE) $(MFLAGS)

libwebsockets/lib/libwebsockets.a: force_look
	cd libwebsockets/lib;$(MAKE) $(MFLAGS)

force_look:
	true

ickSocketDaemon: ickDiscovery.o ickDiscoveryRegistry.o ickP2PComm.o ickSocketDaemon.o
	$(CC) $(LDFLAGS) $(LIBS) $(OBJS) $(MINIUPNPOBJS) $(MINISSDPDOBJS) $(LIBWEBSOCKETSOBJS)  -o ickSocketDaemon
