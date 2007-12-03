#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.61)
AC_INIT(wizbit, 0.1, http://bugzilla.codethink.co.uk)
AM_INIT_AUTOMAKE([1.10])
AC_PROG_LIBTOOL
AM_PROG_CC_C_O

dnl PKG_CHECK_MODULES(GLIB, gobject-2.0 >= 2.6)
PKG_CHECK_MODULES(UUID, uuid >= 1.40)

AC_ARG_WITH(openssl,
  AS_HELP_STRING([--with-openssl],[use OpenSSL library (default is YES)])
  AS_HELP_STRING([],              [ARG can be prefix for openssl library and headers]))

if test "$with_openssl" = "no"; then
  SSL_LIBS=
  SSL_CFLAGS=
else
  PKG_CHECK_MODULES(SSL, libssl)
fi

GIT_LIBS="$SSL_LIBS \$(top_builddir)/git/libgit.a"
GIT_CFLAGS='-I$(top_srcdir)'
AC_SUBST(GIT_LIBS)
AC_SUBST(GIT_CFLAGS)

AC_CONFIG_SUBDIRS([git])
AC_CONFIG_FILES([
Makefile
wizbit/Makefile
test/Makefile
])

AC_OUTPUT
