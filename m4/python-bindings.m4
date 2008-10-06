
AC_DEFUN([AC_WIZ_PYTHON],
 [
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
 ])

