#!/bin/bash

set -e

VERSION=f39

TOOLBOX_NAME=kernel-build

tbrun() {
  toolbox run -c $TOOLBOX_NAME $@
}

toolbox rm -f $TOOLBOX_NAME
rm -rf kernel

trap "toolbox rm -f $TOOLBOX_NAME" EXIT
toolbox create $TOOLBOX_NAME

tbrun sudo dnf install -y fedpkg
tbrun fedpkg clone --anonymous kernel --branch $VERSION --depth 1
cat kernel-patches/* > kernel/linux-kernel-test.patch
cp kernel.config kernel/kernel-local

cd kernel
tbrun sudo dnf builddep -y kernel.spec
powerprofilesctl launch --profile=performance \
  toolbox run -c $TOOLBOX_NAME time -p \
  fedpkg local --without debug
