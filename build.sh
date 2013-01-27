#!/bin/sh
zip -j IckStreamSqueezebox-0.1.`date +%s`.zip daemon/ickSocketDaemon appletlocalplaylist/IckStreamApplet.lua appletlocalplaylist/IckStreamMeta.lua appletlocalplaylist/strings.txt appletlocalplaylist/LICENSE.txt
