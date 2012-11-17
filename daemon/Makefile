CC=gcc
CFLAGS=-Wall -g -rdynamic -DLWS_NO_FORK
LDFLAGS=-g -rdynamic -Wl -lpthread
INTERNALINCLUDES=-I$(CURDIR)/../ickp2p/ickP2P/C/P2P -I$(CURDIR)/../ickp2p/miniupnp/minissdpd -I$(CURDIR)/../ickp2p/miniupnp/miniupnpc -I$(CURDIR)/../ickp2p/libwebsockets/lib -I$(CURDIR)/../ickp2p/jansson/src
JANSSONINCLUDES=-I$(CURDIR)/../ickp2p/jansson/src
#INTERNALINCLUDES=-I../ickp2p/miniupnp/minissdpd -I../ickp2p/miniupnp/miniupnpc -I../ickp2p/libwebsockets/lib -I../ickp2p/jansson/src
RM=rm -f
OBJS=../ickp2p/ickP2P/C/P2P/ickDiscovery.o ../ickp2p/ickP2P/C/P2P/ickDiscoveryRegistry.o ../ickp2p/ickP2P/C/P2P/ickP2PComm.o ickSocketDaemon.o
MINIUPNPOBJS=../ickp2p/miniupnp/miniupnpc/connecthostport.o ../ickp2p/miniupnp/miniupnpc/miniwget.o ../ickp2p/miniupnp/miniupnpc/minixml.o ../ickp2p/miniupnp/miniupnpc/receivedata.o
MINISSDPDOBJS=../ickp2p/miniupnp/minissdpd/openssdpsocket.o ../ickp2p/miniupnp/minissdpd/upnputils.o
LIBWEBSOCKETSOBJS=../ickp2p/libwebsockets/lib/libwebsockets.o ../ickp2p/libwebsockets/lib/sha-1.o ../ickp2p/libwebsockets/lib/parsers.o ../ickp2p/libwebsockets/lib/md5.o ../ickp2p/libwebsockets/lib/handshake.o ../ickp2p/libwebsockets/lib/extension.o ../ickp2p/libwebsockets/lib/base64-decode.o ../ickp2p/libwebsockets/lib/client-handshake.o ../ickp2p/libwebsockets/lib/extension-deflate-stream.o ../ickp2p/libwebsockets/lib/extension-x-google-mux.o
JANSSONOBJS=../ickp2p/jansson/src/value.o ../ickp2p/jansson/src/memory.o ../ickp2p/jansson/src/dump.o ../ickp2p/jansson/src/hashtable.o ../ickp2p/jansson/src/strbuffer.o ../ickp2p/jansson/src/utf.o ../ickp2p/jansson/src/pack_unpack.o ../ickp2p/jansson/src/error.o ../ickp2p/jansson/src/strconv.o
LIBS=-lz
all: $(OBJS) ../ickp2p/miniupnp/minissdpd/libminissdpd.a ../ickp2p/miniupnp/miniupnpc/libminiupnp.a ../ickp2p/libwebsockets/lib/libwebsockets.a ../ickp2p/jansson/src/libjansson.a ickSocketDaemon
DEBUGFLAGS=

clean: 
	$(RM) $(OBJS)
	cd ../ickp2p/miniupnp/minissdpd;$(MAKE) $(MFLAGS) clean
	cd ../ickp2p/miniupnp/miniupnpc;$(MAKE) $(MFLAGS) clean
	$(RM) $(LIBWEBSOCKETOBJS)
	$(RM) $(JANSSONOBJS)

../ickp2p/ickP2P/C/P2P/ickDiscovery.o: ../ickp2p/ickP2P/C/P2P/ickDiscovery.c ../ickp2p/ickP2P/C/P2P/ickDiscovery.h
	cd ../ickp2p/ickP2P/C/P2P;$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o ickDiscovery.o ickDiscovery.c

../ickp2p/ickP2P/C/P2P/ickDiscoveryRegistry.o: ../ickp2p/ickP2P/C/P2P/ickDiscoveryRegistry.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/ickP2P/C/P2P;$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o ickDiscoveryRegistry.o ickDiscoveryRegistry.c

../ickp2p/ickP2P/C/P2P/ickP2PComm.o: ../ickp2p/ickP2P/C/P2P/ickP2PComm.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/ickP2P/C/P2P;$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o ickP2PComm.o ickP2PComm.c

ickSocketDaemon.o: ickSocketDaemon.c ../ickp2p/ickP2P/C/P2P/ickDiscovery.h
	$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o ickSocketDaemon.o ickSocketDaemon.c

../ickp2p/jansson/src/jansson_config.h: force_look
	cp ../ickp2p/jansson/src/jansson_config.h.squeezebox ../ickp2p/jansson/src/jansson_config.h

../ickp2p/miniupnp/minissdpd/libminissdpd.a: force_look
	cd ../ickp2p/miniupnp/minissdpd;$(MAKE) $(MFLAGS)

../ickp2p/miniupnp/miniupnpc/libminiupnp.a: force_look
	cd ../ickp2p/miniupnp/miniupnpc;$(MAKE) $(MFLAGS)

../ickp2p/libwebsockets/lib/libwebsockets.a: ../ickp2p/libwebsockets/lib/libwebsockets.o ../ickp2p/libwebsockets/lib/sha-1.o ../ickp2p/libwebsockets/lib/parsers.o ../ickp2p/libwebsockets/lib/md5.o ../ickp2p/libwebsockets/lib/handshake.o ../ickp2p/libwebsockets/lib/extension.o ../ickp2p/libwebsockets/lib/base64-decode.o ../ickp2p/libwebsockets/lib/client-handshake.o ../ickp2p/libwebsockets/lib/extension-deflate-stream.o ../ickp2p/libwebsockets/lib/extension-x-google-mux.o

../ickp2p/libwebsockets/lib/libwebsockets.o: ../ickp2p/libwebsockets/lib/libwebsockets.c ../ickp2p/libwebsockets/lib/libwebsockets.h
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o libwebsockets.o libwebsockets.c

../ickp2p/libwebsockets/lib/sha-1.o: ../ickp2p/libwebsockets/lib/sha-1.c
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o sha-1.o sha-1.c

../ickp2p/libwebsockets/lib/parsers.o: ../ickp2p/libwebsockets/lib/parsers.c
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o parsers.o parsers.c

../ickp2p/libwebsockets/lib/md5.o: ../ickp2p/libwebsockets/lib/md5.c
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o md5.o md5.c

../ickp2p/libwebsockets/lib/handshake.o: ../ickp2p/libwebsockets/lib/handshake.c
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o handshake.o handshake.c

../ickp2p/libwebsockets/lib/extension.o: ../ickp2p/libwebsockets/lib/extension.c
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o extension.o extension.c

../ickp2p/libwebsockets/lib/base64-decode.o: ../ickp2p/libwebsockets/lib/base64-decode.c
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o base64-decode.o base64-decode.c

../ickp2p/libwebsockets/lib/client-handshake.o: ../ickp2p/libwebsockets/lib/client-handshake.c
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o client-handshake.o client-handshake.c

../ickp2p/libwebsockets/lib/extension-deflate-stream.o: ../ickp2p/libwebsockets/lib/extension-deflate-stream.c ../ickp2p/libwebsockets/lib/extension-deflate-stream.h ../ickp2p/libwebsockets/lib/private-libwebsockets.h
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o extension-deflate-stream.o extension-deflate-stream.c

../ickp2p/libwebsockets/lib/extension-x-google-mux.o: ../ickp2p/libwebsockets/lib/extension-x-google-mux.c ../ickp2p/libwebsockets/lib/extension-x-google-mux.h ../ickp2p/libwebsockets/lib/private-libwebsockets.h
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o extension-x-google-mux.o extension-x-google-mux.c

../ickp2p/jansson/src/libjansson.a: ../ickp2p/jansson/src/value.o ../ickp2p/jansson/src/memory.o ../ickp2p/jansson/src/dump.o ../ickp2p/jansson/src/hashtable.o ../ickp2p/jansson/src/strbuffer.o ../ickp2p/jansson/src/utf.o ../ickp2p/jansson/src/pack_unpack.o ../ickp2p/jansson/src/error.o ../ickp2p/jansson/src/strconv.o

../ickp2p/jansson/src/value.o: ../ickp2p/jansson/src/value.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/jansson/src;$(CC) $(INCLUDES) $(JANSSONINCLUDES) $(CFLAGS) -c -o value.o value.c

../ickp2p/jansson/src/memory.o: ../ickp2p/jansson/src/memory.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/jansson/src;$(CC) $(INCLUDES) $(JANSSONINCLUDES) $(CFLAGS) -c -o memory.o memory.c

../ickp2p/jansson/src/dump.o: ../ickp2p/jansson/src/dump.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/jansson/src;$(CC) $(INCLUDES) $(JANSSONINCLUDES) $(CFLAGS) -c -o dump.o dump.c

../ickp2p/jansson/src/hashtable.o: ../ickp2p/jansson/src/hashtable.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/jansson/src;$(CC) $(INCLUDES) $(JANSSONINCLUDES) $(CFLAGS) -c -o hashtable.o hashtable.c

../ickp2p/jansson/src/strbuffer.o: ../ickp2p/jansson/src/strbuffer.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/jansson/src;$(CC) $(INCLUDES) $(JANSSONINCLUDES) $(CFLAGS) -c -o strbuffer.o strbuffer.c

../ickp2p/jansson/src/utf.o: ../ickp2p/jansson/src/utf.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/jansson/src;$(CC) $(INCLUDES) $(JANSSONINCLUDES) $(CFLAGS) -c -o utf.o utf.c

../ickp2p/jansson/src/pack_unpack.o: ../ickp2p/jansson/src/pack_unpack.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/jansson/src;$(CC) $(INCLUDES) $(JANSSONINCLUDES) $(CFLAGS) -c -o pack_unpack.o pack_unpack.c

../ickp2p/jansson/src/error.o: ../ickp2p/jansson/src/error.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/jansson/src;$(CC) $(INCLUDES) $(JANSSONINCLUDES) $(CFLAGS) -c -o error.o error.c

../ickp2p/jansson/src/strconv.o: ../ickp2p/jansson/src/strconv.c ../ickp2p/jansson/src/jansson_config.h
	cd ../ickp2p/jansson/src;$(CC) $(INCLUDES) $(JANSSONINCLUDES) $(CFLAGS) -c -o strconv.o strconv.c

force_look:
	true

ickSocketDaemon: ../ickp2p/ickP2P/C/P2P/ickDiscovery.o ../ickp2p/ickP2P/C/P2P/ickDiscoveryRegistry.o ../ickp2p/ickP2P/C/P2P/ickP2PComm.o ickSocketDaemon.o
	$(CC) $(LDFLAGS) $(LIBS) $(OBJS) $(MINIUPNPOBJS) $(MINISSDPDOBJS) $(LIBWEBSOCKETSOBJS) $(JANSSONOBJS) -o ickSocketDaemon
