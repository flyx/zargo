#!/bin/sh

set -e

fetch_and_unpack()
{
  URL=$1
  NAME=$(basename "$URL")
  curl --fail -L "$URL" -O
  ar x "$NAME"
  tar xvf data.tar.xz
}

rm -rf tmp arm-linux-gnueabihf && mkdir tmp && cd tmp
while read line; do fetch_and_unpack $line; done < ../arm-linux-gnueabihf.txt
cd .. && mkdir -p arm-linux-gnueabihf/usr
mv tmp/usr/lib/arm-linux-gnueabihf arm-linux-gnueabihf/usr/lib
mv tmp/usr/include arm-linux-gnueabihf/usr/include
mv tmp/lib/arm-linux-gnueabihf arm-linux-gnueabihf/lib