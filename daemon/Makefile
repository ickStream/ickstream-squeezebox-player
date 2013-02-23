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
CFLAGS          = -Wall -g -DLWS_NO_FORK -DGIT_VERSION=$(GITVERSION) -D_GNU_SOURCE
LD		= $(CC)
LDFLAGS		= -g -rdynamic
MKDEPFLAGS	= -Y


# Where to find the: ickstream p2p library
ICKSTREAMDIR	= ../../ickstream-p2p

# Name of executable
EXECUTABLE	= ickSocketDaemon


# Source files to process
SRC             = ickSocketDaemon.c
OBJECTS         = $(SRC:.c=.o)


# Includes and libraries
ZLIBINCLUDES    = 
ZLIBLIBS        = -lz
INCLUDES	= -I$(ICKSTREAMDIR)/include -I$(ZLIBINCLUDES)
LIBDIRS		= -L$(ICKSTREAMDIR)/lib
LIBS		= -lickstreamp2p -lpthread $(ZLIBLIBS)


# How to compile c source files
%.o: %.c
	$(CC) $(INCLUDES) $(CFLAGS) $(DEBUGFLAGS) -c $< -o $@


# Default rule: make all
all: $(ICKSTREAMDIR)/lib/libickstreamp2p.a $(EXECUTABLE)


# Build library
$(ICKSTREAMDIR)/lib/libickstreamp2p.a:
	@echo '*************************************************************'
	@echo "Need to build ickstream p2p library:"
	cd $(ICKSTREAMDIR); make all
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

ickSocketDaemon.o: $(ICKSTREAMDIR)/include/ickDiscovery.h
