/*
  A simple error handling scheme.

  The error structures should be allocated on the stack 
  and passed into the wizbit interface.

  The messages are not freed at any point, so they need to
  be static.
*/

#ifndef WIZ_ERROR_H
#define WIZ_ERROR_H

typedef struct wiz_error_t wiz_error;

/*
  wiz_runtime_error - Sets an error type along with a message.
*/
wiz_error *wiz_runtime_error(const char *err, ...);

/*
 wiz_error_clear - Frees an error.
	
 Sets the return pointer to NULL so that it may be reused.
*/
void wiz_error_clear(wiz_error **error);

/*
  wiz_error_get_message - Get the message associated with the error.
*/
const char *wiz_error_get_message (const wiz_error *error);

/*
  wix_error_get_errno - Get a POSIX errorno representing the error.
*/
int wiz_error_get_errno (const wiz_error *error);

/*
  wiz_error_print - Print the error to stderr.
*/
void wiz_error_print (const wiz_error *error);

#endif /*WIZ_ERROR_H*/
