#!/bin/sh
zip -j IckStreamSqueezebox-0.1.`date +%s`.zip daemon/ickSocketDaemon applet/IckStreamApplet.lua applet/IckStreamMeta.lua applet/strings.txt
