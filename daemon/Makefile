CC=gcc
CFLAGS=-Wall -g -rdynamic -DLWS_NO_FORK -DGIT_VERSION=$(ickstream.ickp2pVersion)
LDFLAGS=-g -rdynamic -Wl -lpthread
INTERNALINCLUDES=-I$(CURDIR)/../ickp2p/ickP2P/C/P2P -I$(CURDIR)/../ickp2p/miniupnp/minissdpd -I$(CURDIR)/../ickp2p/miniupnp/miniupnpc -I$(CURDIR)/../ickp2p/libwebsockets/lib -I$(CURDIR)/../ickp2p/jansson/src
JANSSONINCLUDES=-I$(CURDIR)/../ickp2p/jansson/src
RM=rm -f -v
MKDIR=mkdir -p
OBJS=ickp2p/ickDiscovery.o ickp2p/ickDiscoveryRegistry.o ickp2p/ickP2PComm.o ickSocketDaemon.o
MINIUPNPOBJS=../ickp2p/miniupnp/miniupnpc/connecthostport.o ../ickp2p/miniupnp/miniupnpc/miniwget.o ../ickp2p/miniupnp/miniupnpc/minixml.o ../ickp2p/miniupnp/miniupnpc/receivedata.o
MINISSDPDOBJS=../ickp2p/miniupnp/minissdpd/openssdpsocket.o ../ickp2p/miniupnp/minissdpd/upnputils.o
LIBWEBSOCKETSOBJS=libwebsockets/libwebsockets.o libwebsockets/sha-1.o libwebsockets/parsers.o libwebsockets/md5.o libwebsockets/handshake.o libwebsockets/extension.o libwebsockets/base64-decode.o libwebsockets/client-handshake.o libwebsockets/extension-deflate-stream.o libwebsockets/extension-x-google-mux.o
JANSSONOBJS=../ickp2p/jansson/src/value.o ../ickp2p/jansson/src/memory.o ../ickp2p/jansson/src/dump.o ../ickp2p/jansson/src/hashtable.o ../ickp2p/jansson/src/strbuffer.o ../ickp2p/jansson/src/utf.o ../ickp2p/jansson/src/pack_unpack.o ../ickp2p/jansson/src/error.o ../ickp2p/jansson/src/strconv.o
LIBS=-lz
all: $(OBJS) ../ickp2p/miniupnp/minissdpd/libminissdpd.a ../ickp2p/miniupnp/miniupnpc/libminiupnp.a libwebsockets/libwebsockets.a ../ickp2p/jansson/src/libjansson.a ickSocketDaemon
DEBUGFLAGS=

clean: 
	$(RM) $(OBJS)
	cd ../ickp2p/miniupnp/minissdpd;$(MAKE) $(MFLAGS) clean
	cd ../ickp2p/miniupnp/miniupnpc;$(MAKE) $(MFLAGS) clean
	$(RM) $(LIBWEBSOCKETSOBJS)
	$(RM) $(JANSSONOBJS)

ickp2p/ickDiscovery.o: ../ickp2p/ickP2P/C/P2P/ickDiscovery.c ../ickp2p/ickP2P/C/P2P/ickDiscovery.h
	$(MKDIR) ickp2p
	cd ../ickp2p/ickP2P/C/P2P;$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o $(CURDIR)/ickp2p/ickDiscovery.o ickDiscovery.c

ickp2p/ickDiscoveryRegistry.o: ../ickp2p/ickP2P/C/P2P/ickDiscoveryRegistry.c ../ickp2p/jansson/src/jansson_config.h
	$(MKDIR) ickp2p
	cd ../ickp2p/ickP2P/C/P2P;$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o $(CURDIR)/ickp2p/ickDiscoveryRegistry.o ickDiscoveryRegistry.c

ickp2p/ickP2PComm.o: ../ickp2p/ickP2P/C/P2P/ickP2PComm.c ../ickp2p/jansson/src/jansson_config.h
	$(MKDIR) ickp2p
	cd ../ickp2p/ickP2P/C/P2P;$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o $(CURDIR)/ickp2p/ickP2PComm.o ickP2PComm.c

ickSocketDaemon.o: ickSocketDaemon.c ../ickp2p/ickP2P/C/P2P/ickDiscovery.h
	$(CC) $(INTERNALINCLUDES) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c -o ickSocketDaemon.o ickSocketDaemon.c

../ickp2p/jansson/src/jansson_config.h: force_look
	cp ../ickp2p/jansson/src/jansson_config.h.squeezebox ../ickp2p/jansson/src/jansson_config.h

../ickp2p/miniupnp/minissdpd/libminissdpd.a: force_look
	cd ../ickp2p/miniupnp/minissdpd;$(MAKE) $(MFLAGS)

../ickp2p/miniupnp/miniupnpc/libminiupnp.a: force_look
	cd ../ickp2p/miniupnp/miniupnpc;$(MAKE) $(MFLAGS)

libwebsockets/libwebsockets.a: libwebsockets/libwebsockets.o libwebsockets/sha-1.o libwebsockets/parsers.o libwebsockets/md5.o libwebsockets/handshake.o libwebsockets/extension.o libwebsockets/base64-decode.o libwebsockets/client-handshake.o libwebsockets/extension-deflate-stream.o libwebsockets/extension-x-google-mux.o

libwebsockets/libwebsockets.o: ../ickp2p/libwebsockets/lib/libwebsockets.c ../ickp2p/libwebsockets/lib/libwebsockets.h
	$(MKDIR) libwebsockets
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o $(CURDIR)/libwebsockets/libwebsockets.o libwebsockets.c

libwebsockets/sha-1.o: ../ickp2p/libwebsockets/lib/sha-1.c
	$(MKDIR) libwebsockets
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o $(CURDIR)/libwebsockets/sha-1.o sha-1.c

libwebsockets/parsers.o: ../ickp2p/libwebsockets/lib/parsers.c
	$(MKDIR) libwebsockets
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o $(CURDIR)/libwebsockets/parsers.o parsers.c

libwebsockets/md5.o: ../ickp2p/libwebsockets/lib/md5.c
	$(MKDIR) libwebsockets
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o $(CURDIR)/libwebsockets/md5.o md5.c

libwebsockets/handshake.o: ../ickp2p/libwebsockets/lib/handshake.c
	$(MKDIR) libwebsockets
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o $(CURDIR)/libwebsockets/handshake.o handshake.c

libwebsockets/extension.o: ../ickp2p/libwebsockets/lib/extension.c
	$(MKDIR) libwebsockets
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o $(CURDIR)/libwebsockets/extension.o extension.c

libwebsockets/base64-decode.o: ../ickp2p/libwebsockets/lib/base64-decode.c
	$(MKDIR) libwebsockets
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o $(CURDIR)/libwebsockets/base64-decode.o base64-decode.c

libwebsockets/client-handshake.o: ../ickp2p/libwebsockets/lib/client-handshake.c
	$(MKDIR) libwebsockets
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o $(CURDIR)/libwebsockets/client-handshake.o client-handshake.c

libwebsockets/extension-deflate-stream.o: ../ickp2p/libwebsockets/lib/extension-deflate-stream.c ../ickp2p/libwebsockets/lib/extension-deflate-stream.h ../ickp2p/libwebsockets/lib/private-libwebsockets.h
	$(MKDIR) libwebsockets
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o $(CURDIR)/libwebsockets/extension-deflate-stream.o extension-deflate-stream.c

libwebsockets/extension-x-google-mux.o: ../ickp2p/libwebsockets/lib/extension-x-google-mux.c ../ickp2p/libwebsockets/lib/extension-x-google-mux.h ../ickp2p/libwebsockets/lib/private-libwebsockets.h
	$(MKDIR) libwebsockets
	cd ../ickp2p/libwebsockets/lib;$(CC) $(INCLUDES) $(CFLAGS) -c -o $(CURDIR)/libwebsockets/extension-x-google-mux.o extension-x-google-mux.c

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

ickSocketDaemon: ickp2p/ickDiscovery.o ickp2p/ickDiscoveryRegistry.o ickp2p/ickP2PComm.o ickSocketDaemon.o
	$(CC) $(LDFLAGS) $(LIBS) $(OBJS) $(MINIUPNPOBJS) $(MINISSDPDOBJS) $(LIBWEBSOCKETSOBJS) $(JANSSONOBJS) -o ickSocketDaemon
