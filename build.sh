#!/bin/sh
rm -rf /tmp/IckStream
mkdir /tmp/IckStream
cp applet/IckStreamApplet.lua /tmp/IckStream/.
cp applet/IckStreamMeta.lua /tmp/IckStream/.
cp applet/strings.txt /tmp/IckStream/.
cp daemon/ickSocketDaemon /tmp/IckStream/.
DIR=`pwd`
cd /tmp
zip -r $DIR/IckStreamSqueezebox-0.1.`date +%s`.zip IckStream
cd $DIR
