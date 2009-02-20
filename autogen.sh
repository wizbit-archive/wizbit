#!/bin/sh
# Run this to generate all the initial makefiles, etc.

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

PKG_NAME="wizbit"

USE_COMMON_DOC_BUILD=yes . gnome-autogen.sh
