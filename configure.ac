AC_INIT([wizbit], [0.1.0], [john.carr@unrouted.co.uk], [wizbit])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS(config.h)
AM_INIT_AUTOMAKE([dist-bzip2])
AM_MAINTAINER_MODE

AC_PROG_CC
AM_PROG_CC_C_O
AC_DISABLE_STATIC
AC_PROG_LIBTOOL

AC_PATH_PROG(VALAC, valac, valac)
AC_SUBST(VALAC)

AH_TEMPLATE([GETTEXT_PACKAGE], [Package name for gettext])
GETTEXT_PACKAGE=wizbit
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE")
AC_SUBST(GETTEXT_PACKAGE)
AM_GLIB_GNU_GETTEXT
IT_PROG_INTLTOOL([0.35.0])

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

GLIB_REQUIRED=2.12.0

PKG_CHECK_MODULES(WIZBIT, glib-2.0 >= $GLIB_REQUIRED gobject-2.0 >= $GLIB_REQUIRED gio-2.0 >= $GLIB_REQUIRED gio-unix-2.0 >= $GLIB_REQUIRED uuid >= 1.40)
AC_SUBST(WIZBIT_CFLAGS)
AC_SUBST(WIZBIT_LIBS)

AM_PATH_PYTHON([2.4])

changequote(<<, >>)
PY_VER=`$PYTHON -c 'import distutils.sysconfig; print distutils.sysconfig.get_config_vars("VERSION")[0];'`
PY_LIB=`$PYTHON -c 'import distutils.sysconfig; print distutils.sysconfig.get_python_lib(standard_lib=1);'`
PY_INC=`$PYTHON -c 'import distutils.sysconfig; print distutils.sysconfig.get_config_vars("INCLUDEPY")[0];'`
PY_PREFIX=`$PYTHON -c 'import sys; print sys.prefix'`
PY_EXEC_PREFIX=`$PYTHON -c 'import sys; print sys.exec_prefix'`
changequote([, ])

if test -f $PY_INC/Python.h; then
    PYTHON_LIBS="-L$PY_LIB/config -lpython$PY_VER -lpthread -lutil"
    PYTHON_CFLAGS="-I$PY_INC"
else
    AC_MSG_ERROR([Can't find Python.h])
fi
AC_SUBST(PYTHON_CFLAGS)
AC_SUBST(PYTHON_LIBS)

PKG_CHECK_MODULES(PYGOBJECT, pygobject-2.0 >= 2.8.0)
_
AC_CONFIG_FILES([Makefile
	libwizbit/Makefile
	tests/Makefile
	po/Makefile.in
	python/Makefile])

AC_OUTPUT
