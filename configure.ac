AC_INIT([wizbit], [0.1.0], [john.carr@unrouted.co.uk], [wizbit])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS(config.h)
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([dist-bzip2])
AM_MAINTAINER_MODE

AC_PROG_CC
AM_PROG_CC_C_O
AC_DISABLE_STATIC
AC_PROG_LIBTOOL

AC_PATH_PROG(VALAC, valac, valac)
AC_SUBST(VALAC)

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

GLIB_REQUIRED=2.12.0

PKG_CHECK_MODULES(WIZBIT, glib-2.0 >= $GLIB_REQUIRED gobject-2.0 >= $GLIB_REQUIRED gio-2.0 >= $GLIB_REQUIRED gio-unix-2.0 >= $GLIB_REQUIRED uuid >= 1.40 sqlite3 gtk+-2.0)
AC_SUBST(WIZBIT_CFLAGS)
AC_SUBST(WIZBIT_LIBS)

AC_CONFIG_FILES([
	wizbit.pc
	wizbit-widgets.pc
	Makefile
	wizbit/Makefile
	wizbit-widgets/Makefile
	tests/Makefile
])

AC_OUTPUT
