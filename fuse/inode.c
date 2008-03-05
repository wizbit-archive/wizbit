/*
  WizBit : Git based fuse file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <uuid/uuid.h>

#include <wiz-fs.h>

/*
  make_empty - Makes an empty directory in the file named by dir.

  @dir: File to place a directory in.
  @parent: File containing parent directory structure.
 */
int
fntouuid (char* fname, uuid_t uuid)
{
  if (uuid_parse(fname, uuid) > 0)
     return 0;
  else
     return -ENOMEM;
}

/*
  make_empty - Makes an empty directory in the file named by dir.

  @dir: File to place a directory in.
  @parent: File containing parent directory structure.
 */
int
uuidtofn (uuid_t uuid, char **fname)
{
  char *name = malloc (UUID_STRING_SIZE);

  if (!name)
     return -ENOMEM;

  uuid_unparse_lower(uuid, name);
  *fname = name;
  return 0;
}
