#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <errno.h>

#include "xmalloc.h"
#include "error.h"

struct wiz_error_t {
	char *message;
	int _errno;
};

/*----------------------------------------------------------------------------*/

#define MAX_MESSAGE 255

wiz_error *wiz_runtime_error(const char *err, ...)
{
	va_list params;

	wiz_error *error = xmalloc (sizeof (wiz_error));
	error->_errno = errno;
	error->message = malloc (MAX_MESSAGE);
	va_start(params, err);
	vsnprintf(error->message, MAX_MESSAGE, err, params);
	va_end(params);
	return error;
}

/*----------------------------------------------------------------------------*/

void wiz_error_clear(wiz_error **error) 
{
	free((*error)->message);
	free(*error);
	error = NULL;
}

/*----------------------------------------------------------------------------*/

const char *wiz_error_get_message (const wiz_error *error)
{
	return error->message;
}

/*----------------------------------------------------------------------------*/

int wiz_error_get_errno (const wiz_error *error)
{
	return error->_errno;
}

/*----------------------------------------------------------------------------*/

void wiz_error_print (const wiz_error *error)
{
	fprintf (stderr, "%s", error->message);
}
