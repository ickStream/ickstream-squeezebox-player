#!/bin/sh
BUILDVERSION="0.1.`date +%s`"
rm -rf target
mkdir target
zip -j target/IckStreamSqueezebox-$BUILDVERSION.zip daemon/ickSocketDaemon appletlocalplaylist/IckStreamApplet.lua appletlocalplaylist/IckStreamMeta.lua appletlocalplaylist/strings.txt appletlocalplaylist/LICENSE.txt
sed "s/BUILDVERSION/$BUILDVERSION/" repository-squeezebox.xml > target/repository-squeezebox.xml
