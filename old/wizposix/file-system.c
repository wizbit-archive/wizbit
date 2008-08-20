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

#include <wiz-fs.h>

#include "dir.h"

#define DIR_SEPARATOR '/'
#define ROOT_NAME "/"

#define ROOT_MODE 0664

/*
  TODO - This whole thing is incredibly inefficient.
         If it wasn't for the fact that its being written for GVFS,
         the slowest file system in the world, I'd say it needs a
         hash and tree cache for the DEntries.
 */

/*
  TODO - Worried about permissions attributes.
         Supposedly we should get attributes from the on-disk attributes.
         Althouh this doesn't make sense as the attributes for
         the directories should be executable. 
 */

/*
  get_root_dentry - Gets the dentry of the root path in file system.

  @root: Returns DEntry of the root dir;
 */
static int
get_root_dentry(DEntry **root)
{
  return wiz_create_dentry(root_uuid,
                           WIZ_FT_DIR,
                           "/",
                           root);
}

/*
  get_dir_name - Gets the directory portion of a path.
                 Everything up to the last component.

  @path: Path to get the dir component from.
  @dir: Returns directory component.
 */
static int
get_dir_name(char *path, char **dir)
{
  char *end;
  int len;
  static char *root = ROOT_NAME;

  end = strrchr(path, DIR_SEPARATOR);
  if (end == NULL)
    {
      *dir = NULL;
      *dir = malloc(strlen(root) + 1);
      if (*dir == NULL)
          return -ENOMEM;
      memcpy(dir, root, strlen(root) + 1);
    }
  else
    {
      len = end - path;
      *dir = NULL;
      *dir = malloc(len + 1);
      if (*dir == NULL)
          return -ENOMEM;
      memcpy(dir, root, len);
      dir[len] = '\0';
    }
  return 0;
}

/*----------------------------------------------------------------------------*/

/*
  Functions I want to implement:
  lookup
  create
  link
  unlink
  mkdir
  rmdir
  rename

  readdir

  TODO - Support symlinks.
 */

/*
  wiz_create_fs - Creates a blank file system in given base.

  Really temporary, just takes the base and creates a root
  directory inside it.

  FIXME - Does there need to be anything special about the
          root directory? Does it have its own type?

          When loading into say fuse, how does the ".." dir
          link up to the parent path?
 */
int
wiz_create_fs (char* base)
{
  DEntry *root;
  int err = 0;

  err = get_root_dentry(&root);
  if (err != 0)
      return err;

  /* ATM the root dir is its own parent */
  /* What is the correct mode of the root dir? */
  err = wiz_dir_make_empty(base, root->f_uuid, root->f_uuid, ROOT_MODE);
  free(root);
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
wiz_lookup (char* base, char *path, DEntry **entry)
{
  DEntry *find;
  DEntry *next;
  char **components = NULL;

  int err = 0;
  int i;

  /*
  if (*path != DIR_SEPARATOR)
      return -EINVAL;
   */

  err = get_root_dentry(entry);
  if (err != 0)
      return err;

  err = split_path(path, &components);
  if (err != 0)
      return err;

  for (i=0; components[i] != 0; i++)
    {
      err = wiz_create_dentry(null_uuid,
                              0,
                              components[i],
                              &find);
      if (err != 0)
        {
          wiz_delete_dentry(*entry);
          break;
        }
      err = wiz_dir_find_entry(base,
                               (*entry)->f_uuid,
                               find,
                               &next);
      if (err != 0)
        {
          wiz_delete_dentry(*entry);
          free(find);
          break;
        }
      wiz_delete_dentry(*entry);
      *entry = next;
    }

  for (i=0; components[i] != 0; i++)
    {
      free(components[i]);
    }
  free(components);

  return err;
}

/*
  wiz_create - Creates a regular file at the path specified,
               with name specified by DEntry.
 */
int
wiz_create(char *base, char *path, DEntry *entry, mode_t mode)
{
  uuid_t n;
  int fd;
  char *fn;
  DEntry *dir;
  int err = 0;

  if (entry->file_type != WIZ_FT_REG_FILE)
      return -EINVAL;

  uuid_generate(n);
  wiz_uuidtofn (base, n, &fn);

  /* TODO - Use creat */
  fd = open(fn, O_RDWR | O_CREAT, mode);
  free(fn);
  if (fd < 0)
      return -EIO;
  close(fd);

  err = wiz_lookup(base, path, &dir);
  if (err != 0)
      return err;
  err = wiz_dir_add_link(base, dir->f_uuid, entry);
  free(dir);
  memcpy(entry->f_uuid, n, sizeof(uuid_t));
  return err;
}

/*
  wiz_link - Links the specified entry with the directory
             found at path.

  Makes no checks to see if entry really exists.
 */
int
wiz_link(char *base, char *path, DEntry *entry)
{
  DEntry *dir;
  int err = 0;

  err = wiz_lookup(base, path, &dir);
  if (err != 0)
      return err;
  err = wiz_dir_add_link(base, dir->f_uuid, entry);
  free(dir);
  return err;
}

/*
  wiz_unlink - Unlinks the specified entry from the dir
               specified by path.
 */
int
wiz_unlink(char *base, char *path, DEntry *entry)
{
  DEntry *dir;
  int err = 0;

  err = wiz_lookup(base, path, &dir);
  if (err != 0)
      return err;
  err = wiz_dir_remove_link(base, dir->f_uuid, entry);
  free(dir);
  return err;
}

/*
  wiz_mkdir - Makes an empty directory, name given by entry in
              dir specified by path.
 */
int
wiz_mkdir(char *base, char *path, DEntry *entry, mode_t mode)
{
  uuid_t n;
  DEntry *dir;
  int err = 0;

  if (entry->file_type != WIZ_FT_DIR)
      return -EINVAL;

  uuid_generate(n);
  err = wiz_lookup(base, path, &dir);
  if (err != 0)
      return err;
  err = wiz_dir_make_empty(base, n, dir->f_uuid, mode);
  if (err != 0)
    {
      free(dir);
      return err;
    }
  memcpy(entry->f_uuid, n, sizeof(uuid_t));
  err = wiz_dir_add_link(base, dir->f_uuid, entry);
  free(dir);
  return err;
}

/*
  wiz_rmdir - Removes a directory specified by entry from
              the dir given by path.
 */
int
wiz_rmdir(char *base, char *path, DEntry *entry)
{
  DEntry *dir;
  int err = 0;

  err = wiz_lookup(base, path, &dir);
  if (err != 0)
      return err;
  err = wiz_dir_remove_link(base, dir->f_uuid, entry);
  free(dir);
  return err;
}

/*
  wiz_rename - Moves a file with DEntry old in oldpath
               to newpath with DEntry new.
 */
int
wiz_rename(char *base, char *oldpath, DEntry *old,
                       char *newpath, DEntry *new)
{
  DEntry *olddir;
  DEntry *newdir;
  int err = 0;

  err = wiz_lookup(base, oldpath, &olddir);
  if (err != 0)
      return err;
  err = wiz_dir_remove_link(base, olddir->f_uuid, old);
  free(olddir);
  if (err != 0)
      return err;

  memcpy(new->f_uuid, old->f_uuid, sizeof(uuid_t));
  new->file_type = old->file_type;

  err = wiz_lookup(base, newpath, &newdir);
  if (err != 0)
      return err;
  err = wiz_dir_add_link(base, newdir->f_uuid, new);
  free(newdir);

  return err;
}

/*
  wiz_readdir - Gets a null terminated array of DEntry structs,
                representing all entries in the directory.
 */
int
wiz_readdir(char *base, char *path, DEntry ***list)
{
  DEntry *dir;
  int err = 0;

  err = wiz_lookup(base, path, &dir);
  if (err != 0)
      return err;
  err = wiz_dir_list_entries(base, dir->f_uuid, list);
  free(dir);
  return err;
}

#if WIZ_DEVEL
int
wiz_print_dir (char *base, char *path)
{
  DEntry *dir;
  int err = 0;
  DEntry **list;
  char *fn;
  int i;

  err = wiz_lookup(base, path, &dir);
  if (err != 0)
      return err;
  err = wiz_dir_list_entries(base, dir->f_uuid, &list);
  if (err != 0)
    {
      free(dir);
      return err;
    }
  err = wiz_uuidtofn (base, dir->f_uuid, &fn);
  free(dir);
  if (err != 0)
      return err;

  printf("\n-------------------------------------\n");
  printf("Directory - %s\n\n", fn);
  free(fn);

  for (i=0; list[i] != NULL; i++)
    {
      char *uuids;

      wiz_uuidtofn(base, (list[i])->f_uuid, &uuids);
      printf("uuid: %s\nname_len: %d\nfile_type: %d\nname: %s\n\n",
             uuids,
             (list[i])->name_len,
             (list[i])->file_type,
             (list[i])->name);
      free(uuids);
      wiz_delete_dentry(list[i]);
    }
  free(list);
  return err;
}
#endif
