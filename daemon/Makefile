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
# --------------------------------------------------------------

# *************************************************************************
# Copyright (c) 2013, ickStream GmbH
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright 
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright 
#     notice, this list of conditions and the following disclaimer in the 
#     documentation and/or other materials provided with the distribution.
#   * Neither the name of ickStream nor the names of its contributors 
#     may be used to endorse or promote products derived from this software 
#     without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# ************************************************************************

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
