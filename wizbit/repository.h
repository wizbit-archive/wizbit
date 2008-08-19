/*
  Repository class
 
  Responsible for creating a repository
  and for checking & commiting file
  data and meta-data.
*/

#ifndef WIZ_REPOSITORY_H
#define WIZ_REPOSITORY_H

#include <fcntl.h>

#include "error.h"
#include "ref-store.h"

typedef struct wiz_repository_t wiz_repository;
typedef struct wiz_file_store_t wiz_file_store;


/* Repository operations.                                                     */
/*----------------------------------------------------------------------------*/

/*
  wiz_repository_create

  Constructor for wiz-repository.

  Creates a wizbit repository at the directory supplied.
  If a repository structure is already present at that
  location it returns an error.
*/
wiz_repository *wiz_repository_create(char *dpath, wiz_error **err);

/*
  wiz_repository_access
 
  Constructor for wiz-repository.

  Accesses a wizbit repository at the directory supplied.
  If a repository structure is not present in that directory
  it returns an error.
*/
wiz_repository *wiz_repository_access(char *dpath, wiz_error **err);

/*
  wiz_repository_free - Frees memory and resources for the repository structure.
*/
void wiz_repository_free(wiz_repository *repo);

/* 
  wiz_repository_create_store - Creates a new file store within the repository.

  This will initially be represented by the object
  sha1 0000-0000-0000-0000, an empty file.
*/
wiz_file_store *wiz_repository_create_store(wiz_repository *repo, 
					    mode_t mode, 
					    wiz_error **err);

/* 
  wiz_repository_get_store - Gets the file store given by uuid s_uuid
*/ 
wiz_file_store *wiz_repository_checkout_store(wiz_repository *repo,
					      uuid_t s_uuid,
					      wiz_reference ref,
					      char *path,
					      wiz_error **err);

#endif /* WIZ_REPOSITORY_H */
