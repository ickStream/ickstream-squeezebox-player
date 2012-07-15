CC=gcc
CFLAGS=-Wall -g -rdynamic
LDFLAGS=-shared -g -rdynamic -Wl -lpthread
RM=rm -f
OBJS=connecthostport.o miniwget.o minixml.o receivedata.o

all: $(OBJS)

clean: 
	$(RM) $(OBJS)

connecthostport.o: connecthostport.c connecthostport.h
	$(CC) $(CFLAGS) -c -o connecthostport.o connecthostport.c

miniwget.o: miniwget.c miniwget.h
	$(CC) $(CFLAGS) -c -o miniwget.o miniwget.c

minixml.o: minixml.c minixml.h
	$(CC) $(CFLAGS) -c -o minixml.o minixml.c

receivedata.o: receivedata.c receivedata.h
	$(CC) $(CFLAGS) -c -o receivedata.o receivedata.c

