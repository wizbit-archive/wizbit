/*
  Some simple path manipulation
  functions. 
*/

#ifndef WIZ_PATH_H
#define WIZ_PATH_H

#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <error.h>
 
/*
  wiz_path_chop_end - Returns the last element of a path.

  @path: Path to return the last element of.
  @start: Newly allocated pointer to the beginning part of the path.

  @returns: Newly allocated pointer to last element of path.
*/
char *wiz_path_chop_end(char *path, char **start);

/*
  wiz_path_chop_start - Returns the first element of the path.

  The element does not include drive or '/' characters if the 
  path is absolute.

  @path: Path to return the first element of.
  @end: Returns a pointer into the path string with the rest of the path.

  @returns: The first element of the provided path or NULL if there is an error.
*/
char *wiz_path_chop_start(char *path, char **end);

/*
  wiz_path_join - Join n path elements
  
  If any of the paths provided are absolute then the final
  path is also absolute.

  @args: Path elements to join into single path.

  @returns: Final joined path.
*/
char *wiz_path_join(const char *fst, ...);

#endif /* WIZ_PATH_H */
