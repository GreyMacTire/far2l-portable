#!/bin/bash

REPO_DIR=$GITHUB_WORKSPACE
export CCACHE_DIR=$REPO_DIR/.ccache
export DESTDIR=$REPO_DIR/AppDir
BUILD_DIR=build

if [[ $(awk -F= '/^ID=/ {print $2}' /etc/os-release) == "alpine" ]]; then
  CMAKE_OPTS+=( "-DMUSL=ON" )
fi
if [[ "$STANDALONE" == "true" ]]; then
  CMAKE_OPTS+=( "-DUSEWX=no" )
fi
if [[ "$PLUGINS_EXTRA" == "true" ]]; then
  for plug in netcfgplugin sqlplugin processes ; do
    git clone --depth 1 https://github.com/VPROFi/$plug.git && \
    ( cd $plug && \
      find . -mindepth 1 -name 'src' -prune -o -exec rm -rf {} + && \
      mv src/* . && rm -rf src )
    echo "add_subdirectory($plug)" >> CMakeLists.txt
  done
fi
if [[ "$PLUGINS" == "false" ]]; then
  CMAKE_OPTS+=( "-DCOLORER=no -DNETROCKS=no -DALIGN=no -DAUTOWRAP=no -DCALC=no \
    -DCOMPARE=no -DDRAWLINE=no -DEDITCASE=no -DEDITORCOMP=no -DFILECASE=no \
    -DINCSRCH=no -DINSIDE=no -DMULTIARC=no -DSIMPLEINDENT=no -DTMPPANEL=no" )
fi

QUILT_PATCHES=$REPO_DIR/patches quilt push -a

mkdir -p $BUILD_DIR && \
( cd $BUILD_DIR && \
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DCMAKE_C_COMPILER_LAUNCHER=/usr/bin/ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=/usr/bin/ccache \
    ${CMAKE_OPTS[@]} .. && \
    ninja && ninja install/strip ) && \

tar cJvf $REPO_DIR/far2l.tar.xz -C $REPO_DIR/AppDir .

if [[ "$STANDALONE" == "true" ]]; then
  ( cd $BUILD_DIR/install && ./far2l --help >/dev/null && bash -x $REPO_DIR/make_standalone.sh ) && \
  ( cd $REPO_DIR && makeself --keep-umask far2l/$BUILD_DIR/install $PKG_NAME.run "FAR2L File Manager" ./far2l && \
    tar cvf ${PKG_NAME/_${VERSION}}.run.tar $PKG_NAME.run )
fi

ccache --max-size=50M --show-stats
