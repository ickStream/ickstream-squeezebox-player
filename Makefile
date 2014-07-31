# --------------------------------------------------------------
#
# Description     : makefile for the ickStream Squeezebox plugin
#
# Comments        : -
#
# Date            : 22.09.2013
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

WEBSOCKETSDIR = $(CURDIR)/libwebsockets
ICKSTREAMDIR = $(CURDIR)/ickstream-p2p
ROOTFS = /usr/src/poky/build/tmp-jive/staging/armv5te-none-linux-gnueabi

BUILDVERSION := 0.1.$(shell date +%s)

CC=/usr/src/poky/build/tmp-jive/cross/armv5te/bin/arm-none-linux-gnueabi-gcc

all: daemon/ickSocketDaemon

target/libwebsockets/Makefile:
	mkdir -p target/libwebsockets
	cd target/libwebsockets;cmake $(WEBSOCKETSDIR) -DWITH_SSL=0 -DCMAKE_TOOLCHAIN_FILE=$(CURDIR)/Squeezebox.cmake

target/libwebsockets/lib/libwebsockets.a: target/libwebsockets/Makefile
	@echo '*************************************************'
	@echo "Need to build libwebsockets library:"
	cd target/libwebsockets;make 
	@echo '*************************************************'

$(ICKSTREAMDIR)/lib/libwebsockets.a: target/libwebsockets/lib/libwebsockets.a
	mkdir -p $(ICKSTREAMDIR)/lib
	cp target/libwebsockets/lib/libwebsockets.a $(ICKSTREAMDIR)/lib/.

$(ICKSTREAMDIR)/lib/libz.so.1:
	mkdir -p $(ICKSTREAMDIR)/lib
	cp $(ROOTFS)/usr/lib/libz.so.1 $(ICKSTREAMDIR)/lib/.

$(ICKSTREAMDIR)/lib/libickp2p.a: $(ICKSTREAMDIR)/lib/libwebsockets.a $(ICKSTREAMDIR)/lib/libz.so.1
	@echo '*************************************************'
	@echo "Need to build ickp2p library:"
	cd $(ICKSTREAMDIR);make debug INCLUDES=-I$(WEBSOCKETSDIR)/lib CC=$(CC)
	@echo '*************************************************'

daemon/ickSocketDaemon: $(ICKSTREAMDIR)/lib/libickp2p.a
	cd daemon;make ICKSTREAMDIR=$(ICKSTREAMDIR) ROOTFS=$(ROOTFS) CC=$(CC)

clean:
	@echo '*************************************************************'
	@echo "Deleting intermediate files:"
	cd $(ICKSTREAMDIR);make clean
	cd target/libwebsockets;make clean
	cd daemon;make clean

cleanall: 
	@echo '*************************************************************'
	@echo "Clean all:"
	cd $(ICKSTREAMDIR);make cleanall
	cd daemon;make cleanall
	rm -rf target

dist: daemon/ickSocketDaemon
	zip -j target/IckStreamSqueezebox-$(BUILDVERSION).zip daemon/ickSocketDaemon appletlocalplaylist/IckStreamApplet.lua appletlocalplaylist/IckStreamMeta.lua appletlocalplaylist/strings.txt appletlocalplaylist/LICENSE.txt
	sed "s/BUILDVERSION/$(BUILDVERSION)/" repository-squeezebox.xml > target/repository-squeezebox.xml
