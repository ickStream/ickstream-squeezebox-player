# --------------------------------------------------------------
#
# Description     : makefile for the ickSocketDaemon
#
# Comments        : -
#
# Date            : 17.02.2013
#
# Updates         :
#
# Author          : 
#                  
# Remarks         : -
#
# Copyright (c) 2013 ickStream GmbH.
# All rights reserved.
# --------------------------------------------------------------

CC              = cc
CFLAGS          = -Wall -g -DICK_DEBUG -DLWS_NO_FORK -DGIT_VERSION=$(GITVERSION) -D_GNU_SOURCE
LD		= $(CC)
LDFLAGS		= -g -rdynamic
MKDEPFLAGS	= -Y


# Where to find the: ickp2p library
ICKSTREAMDIR	= ../ickstream-p2p

# Name of executable
EXECUTABLE	= ickSocketDaemon


# Source files to process
SRC             = ickSocketDaemon.c
OBJECTS         = $(SRC:.c=.o)


# Includes and libraries
#WEBSOCKETSINCLUDES    = 
#WEBSOCKETSLIBS = -lwebsockets
#ZLIBINCLUDES    = 
#ZLIBLIBS        = -lz
INCLUDES	= -I$(ICKSTREAMDIR)/include
LIBDIRS		= -L$(ICKSTREAMDIR)/lib -L$(ROOTFS)/usr/lib
LIBS		= -lickp2p -lpthread -lz -lwebsockets


# How to compile c source files
%.o: %.c
	$(CC) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c $< -o $@


# Default rule: make all
all: $(ICKSTREAMDIR)/lib/libp2p.a $(EXECUTABLE)


# Build library
$(ICKSTREAMDIR)/lib/libp2p.a:
	@echo '*************************************************************'
	@echo "Need to build ickp2p library:"
	cd $(ICKSTREAMDIR); make debug INCLUDES=-I$(WEBSOCKETSINCLUDES)
	@echo '*************************************************************'


# Build target
$(EXECUTABLE): $(OBJECTS)
	@echo '*************************************************************'
	@echo "Linking executable:"
	$(LD) $(LDFLAGS) $(LIBDIRS) $(OBJECTS) $(LIBS)  -o $@


# How to update from git
update:
	@echo '*************************************************************'
	@echo "Updating from git repository:"
	git pull --recurse-submodules
	git submodule update --recursive


# How to create dependencies
depend:
	@echo '*************************************************************'
	@echo "Creating dependencies:"
	makedepend $(MKDEPFLAGS) -- $(INCLUDES) $(CFLAGS) -- $(SRC) 2>/dev/null


# How to clean tempoarary files
clean:
	@echo '*************************************************************'
	@echo "Deleting intermediate files:"
	rm -f $(OBJECTS)


# How to clean all
cleanall: clean
	@echo '*************************************************************'
	@echo "Clean all:"
	rm -rf $(EXECUTABLE)

# End of Makefile -- makedepend output might follow ...

# DO NOT DELETE

ickSocketDaemon.o: $(ICKSTREAMDIR)/include/ickP2p.h
