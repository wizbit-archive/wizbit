/*
  WizBit : Git based file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <uuid/uuid.h>
#include <stdio.h>
#include <unistd.h>

#include <wiz-file-store.h>
#include <wiz-directory.h>
#include <wiz-directory-entry.h>

#define DIR_SEPARATOR '/'
#define ROOT_NAME "/"

#define ROOT_MODE 0664

static DEntry root_dentry = {
  {0},
  WIZ_FT_DIR,
  1,
  ROOT_NAME
};

/*
  split_path - Splits a path into an array of components.

  @path: Path that needs splitting.

  @components: Returns null terminated array of null terminated strings.

  FIXME - There are a whole lot of assumptions going on here
          about the nature of the passed path.
  FIXME - strchrnul is a gnu extension.
 */
static int
split_path (char *path, char ***components)
{
  int numc = 0;
  int count = 0;
  int len;
  char *comp;

  char *cur = path;
  char *prev = NULL;

  if (*components != NULL)
      return -EINVAL;

  while (*cur == DIR_SEPARATOR)
      cur++;
  while (*cur != '\0')
    {
      numc++;
      cur = (char *) strchrnul(cur, DIR_SEPARATOR);
      while (*cur == DIR_SEPARATOR)
          cur++;
    }

  *components = malloc((numc+1) * sizeof(char *));
  if (*components == NULL)
     return -ENOMEM;

  cur = path;
  while (*cur == DIR_SEPARATOR)
      cur++;
  while (*cur != '\0')
    {
      prev = cur;
      cur = (char *) strchrnul(cur, DIR_SEPARATOR);
      len = cur - prev;
      comp = NULL;
      comp = malloc((len+1) * sizeof(char));
      if (comp == NULL)
        {
          (*components)[count] = NULL;
          goto error;
        }
      memcpy(comp, prev, len);
      comp[len] = '\0';
      (*components)[count++] = comp;
      while (*cur == DIR_SEPARATOR)
          cur++;
    }
  (*components)[count] = NULL;
  return 0;

error:
  count = 0;
  comp = (*components)[count++];
  while (comp != NULL)
    {
      free(comp);
      comp = (*components)[count++];
    }
  free(components);
  return -ENOMEM;
}

/*----------------------------------------------------------------------------*/

/*
  wiz_directory_file_system_create - Creates a blank file system in given fstore.

  FIXME - Does there need to be anything special about the
          root directory? Does it have its own type?

          When loading into say fuse, how does the ".." dir
          link up to the parent path?
 */
int
wiz_directory_file_system_create (FileStore *fstore)
{
  int err = 0;
  int fd;

  err = wiz_file_store_create_file_uuid(fstore, ROOT_MODE, root_dentry->f_uuid, &fd);
  if (err != 0)
      return err;
  err = wiz_directory_make_empty (fd, root_dentry->f_uuid, root_dentry->f_uuid);
  close(fd);
  return err;
}

/*
  wiz_lookup - Converts a given path to a DEntry.

  @base: The base directory (Where to find repositories)
  @path: The path to convert to a dentry.
  @entry: Returns the found DEntry, undefined on error.

  Path must be absolute.
 */
int
wiz_directory_file_system_lookup (FileStore *fstore, char *path, DEntry **entry)
{
  DEntry find;
  char **components = NULL;

  int err = 0;
  int i;
  int fd;

  err = split_path(path, &components);
  if (err != 0)
      return err;

  memcpy(find->f_uuid, root_dentry->f_uuid, sizeof(uuid_t));

  for (i=0; components[i] != NULL; i++)
    {
      err = wiz_file_store_open(find->f_uuid, &fd);
      if (err != 0)
          break;
      find.name = components[i];
      err = wiz_directory_entry_find_entry(fd, &find);
      close(fd);
    }

  for (i=0; components[i] != 0; i++)
    {
      free(components[i]);
    }
  free(components);

  return err;
}
