#!/bin/bash
dir=`pwd`
skynet=$dir/skynet
clib=$dir/clib
mkdir -p clib

rm -rf $skynet
cd skynet-src
# chmod -R 777 *
sh mkskynet.sh

cd $dir/src
make clean OUT_PATH=$clib
make OUT_PATH=$clib SKYNET=$dir/skynet-src

# cd $dir
# chmod -R 777 $skynet
# chmod -R 777 $clib

cd $dir/3rd/lua-cjson
make clean
make
\cp cjson.so $OutDir/luaclib/ -fr
make clean
