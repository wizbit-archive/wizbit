/*
  WizBit : Git based file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <stdio.h>
#include <string.h>
#include <uuid/uuid.h>
#include <inttypes.h>

#include <wizbit/file-store.h>

#include "directory-entry.h"

/* wiz_dir_entry - The on disk format of a directory entry*/
typedef struct
{
  uuid_t f_uuid;
  uint16_t rec_len;
  char name_len;
  char file_type;
  char name [];
} wiz_dir_entry;

static int
match (char *name, int len, DEntry *entry)
{
  if (entry->name_len != len)
     return -1;
  return strncmp(name, entry->name, len);
}

/*
  make_empty - Makes an empty directory in the file named by dir.

  @dir: File to place a directory in.
  @parent: File containing parent directory structure.
 */
int
wiz_dir_make_empty (char *dir, DEntry *parent, mode_t mode)
{
  int err;
  int rec_len;
  wiz_dir_entry *entry;

  int fd;
  FILE *f;

  fd = open(dir, O_WRONLY | O_TRUNC, mode);
  free(fn);
  if (fd < 0)
      return -errno;
  f = (FILE*) fdopen(fd, "w");

  entry = (wiz_dir_entry*) malloc(sizeof(wiz_dir_entry) + 2);

  rec_len = sizeof(wiz_dir_entry) + 1;
  memcpy(entry->f_uuid, dir, sizeof(uuid_t));
  entry->name_len = 1;
  entry->rec_len = htons(rec_len);
  entry->file_type = WIZ_FT_DIR;
  memcpy(entry->name, ".", entry->name_len);
  fwrite(entry, rec_len, 1, f);

  rec_len = sizeof(wiz_dir_entry) + 2;
  memcpy(entry->f_uuid, parent->f_uuid, sizeof(uuid_t));
  entry->name_len = 2;
  entry->rec_len = htons(rec_len);
  entry->file_type = WIZ_FT_DIR;
  memcpy(entry->name, "..", entry->name_len);
  fwrite(entry, rec_len, 1, f);

  fclose(f);
  return 0;
}

/*
  add_link - Adds a directory entry to the given directory.

  @dir: Directory to add link to.
  @de: Entry to place into the directory.
 */
int
wiz_dir_add_link (char *dir, DEntry* de)
{
  int err = 0;
  int fd;
  char *buf;
  char *f;
  char *end;
  struct stat statbuf;
  int rec_len;
  int prev_rec_len;
  wiz_dir_entry *entry;
  wiz_dir_entry *new_entry;

  fd = open(dir, O_RDWR);
  if (fd < 0)
     return -errno;

  err = fstat (fd, &statbuf);
  if (err < 0)
    {
      err = -errno;
      goto out;
    }

  buf = f = mmap(0, statbuf.st_size, PROT_READ | PROT_WRITE,
                 MAP_SHARED, fd, 0);
  if ((int) f == -1)
    {
      err = -EIO;
      goto out;
    }

  end = f + statbuf.st_size;
  rec_len = sizeof(wiz_dir_entry) + de->name_len;

  while (f < end)
    {
      int room_left;

      entry = (wiz_dir_entry*) f;
      if (!match(entry->name, entry->name_len, de))
        {
           err = -EEXIST;
           goto out;
        }
      room_left = ntohs(entry->rec_len)
                  -sizeof(wiz_dir_entry) - entry->name_len;
      if (room_left >= rec_len)
        {

           prev_rec_len = sizeof(wiz_dir_entry) + entry->name_len;
           new_entry = (wiz_dir_entry*) (f + prev_rec_len);
           memcpy(new_entry->f_uuid, de->f_uuid, sizeof(uuid_t));
           new_entry->name_len = de->name_len;
           new_entry->rec_len = htons(ntohs(entry->rec_len) - prev_rec_len);
           new_entry->file_type = de->file_type;
           memcpy(new_entry->name, de->name, de->name_len);
           entry->rec_len = htons(prev_rec_len);
           goto out;
        }
      f += ntohs(entry->rec_len);
    }

  /*
    If we have reached this point then no room was found
    for the entry in the records, need to append to end.
   */
  munmap(buf, statbuf.st_size);
  if (lseek (fd, rec_len - 1, SEEK_END) == -1)
    {
      err = -errno;
      goto out;
    }
  /* write a dummy byte at the last location */
  if (write (fd, "", 1) != 1)
    {
      err = -errno;
      goto out;
    }
  buf = f = mmap(0, statbuf.st_size + rec_len, PROT_READ | PROT_WRITE,
                 MAP_SHARED, fd, 0);
  if ((int) f == -1)
    {
      err = -EIO;
      goto out;
    }

  f += statbuf.st_size;
  new_entry = (wiz_dir_entry*) f;
  memcpy(new_entry->f_uuid, de->f_uuid, sizeof(uuid_t));
  new_entry->name_len = de->name_len;
  new_entry->rec_len = htons(rec_len);
  new_entry->file_type = de->file_type;
  memcpy(new_entry->name, de->name, de->name_len);

out:
  close(fd);
  free(fn);
  return err;
}

/*
  remove_link - Removes a link with name de->name from the directory.

  @dir: Directory to remove link from.
  @de: Directory entry containing name of link to be removed.
 */
int
wiz_dir_remove_link (char *dir, DEntry *de)
{
  int err = 0;
  int fd;
  char *buf, *f;
  char *end;
  struct stat statbuf;
  wiz_dir_entry *entry = NULL;
  wiz_dir_entry *prev_entry = NULL;

  fd = open(dir, O_RDWR);
  if (fd < 0)
     return -errno;

  err = fstat (fd, &statbuf);
  if (err < 0)
    {
      err = -errno;
      goto out;
    }

  buf = f = mmap(0, statbuf.st_size, PROT_READ | PROT_WRITE,
                 MAP_SHARED, fd, 0);
  if ((int) f == -1)
    {
      err = -EIO;
      goto out;
    }

  end = f + statbuf.st_size;

  while (f < end)
    {
      prev_entry = entry;
      entry = (wiz_dir_entry*) f;
      if (!match(entry->name, entry->name_len, de))
        {
           char *f_next;
           int to_remove;
           if (!prev_entry)
             {
               err = -EINVAL;
               goto out;
             }
           /* Delete by merging with prev record*/
           prev_entry->rec_len = htons(ntohs(prev_entry->rec_len) +
                                       ntohs(entry->rec_len));
           /* Is this the last entry ?*/
           f_next = f + ntohs(entry->rec_len);
           if (f_next >= end)
             {
               to_remove = ntohs(prev_entry->rec_len) -
                                 sizeof(wiz_dir_entry) -
                                 prev_entry->name_len;
               err = truncate (fn, statbuf.st_size - to_remove);
               prev_entry->rec_len = htons(sizeof(wiz_dir_entry) + prev_entry->name_len);
             }
           goto out;
        }
      f += ntohs(entry->rec_len);
    }

  /*
    If we have reached this point then no record was
    found that matches.
   */
  err = -ENOENT;

out:
  close(fd);
  free(fn);
  return err;
}

/*
  set_link - Sets the link given by de->name to the given UUID, file.

  @dir: Directory to modify.
  @de: Directory entry with name of link to modify.
  @file: New UUID to set the directory entry to.
 */
int wiz_dir_set_link (char *dir, DEntry *de, uuid_t file)
{
  int err = 0;
  int fd;
  char *fn;
  char *buf, *f;
  char *end;
  struct stat statbuf;
  wiz_dir_entry *entry = NULL;

  err = wiz_uuidtofn(base, dir, &fn);
  if (err)
     return err;

  fd = open(fn, O_RDWR);
  if (fd < 0)
     return -errno;

  err = fstat (fd, &statbuf);
  if (err < 0)
    {
      err = -errno;
      goto out;
    }

  buf = f = mmap(0, statbuf.st_size, PROT_READ | PROT_WRITE,
                 MAP_SHARED, fd, 0);
  if ((int) f == -1)
    {
      err = -EIO;
      goto out;
    }

  end = f + statbuf.st_size;

  while (f < end)
    {
      entry = (wiz_dir_entry*) f;
      if (!match(entry->name, entry->name_len, de))
        {
           memcpy(entry->f_uuid, file, sizeof(uuid_t));
           goto out;
        }
      f += ntohs(entry->rec_len);
    }

  /*
    If we have reached this point then no record was
    found that matches.
   */
  err = -ENOENT;

out:
  close(fd);
  free(fn);
  return err;
}

/*
  find_entry - Searches through the directory entries for a given name.

  @dir: Directory to search.
  @de: Directory entry containing name of entry to search for.
  @res: Returns the directory entry if found, NULL otherwise.
 */
int wiz_dir_find_entry (char *dir, DEntry *de, DEntry **res)
{
  int err = 0;
  int fd;
  char *buf, *f;
  char *end;
  struct stat statbuf;
  wiz_dir_entry *entry = NULL;

  fd = open(dir, O_RDWR);
  if (fd < 0)
     return -errno;

  err = fstat (fd, &statbuf);
  if (err < 0)
    {
      err = -errno;
      goto out;
    }

  buf = f = mmap(0, statbuf.st_size, PROT_READ | PROT_WRITE,
                 MAP_SHARED, fd, 0);
  if ((int) f == -1)
    {
      err = -EIO;
      goto out;
    }

  end = f + statbuf.st_size;

  while (f < end)
    {
      entry = (wiz_dir_entry*) f;
      if (!match(entry->name, entry->name_len, de))
        {
           *res = malloc(sizeof(DEntry));
           if (!*res)
             {
               err = -ENOMEM;
               goto out;
             }
           memcpy((*res)->f_uuid, entry->f_uuid, sizeof(uuid_t));
           (*res)->name_len = entry->name_len;
           (*res)->file_type = entry->file_type;
           (*res)->name = malloc(entry->name_len + 1);
           ((*res)->name)[(int) entry->name_len] = '\0';
           memcpy((*res)->name, entry->name, entry->name_len);
           goto out;
        }
      f += ntohs(entry->rec_len);
    }

  /*
    If we have reached this point then no record was
    found that matches.
   */
  *res = NULL;
  err = -ENOENT;

out:
  close(fd);
  free(fn);
  return err;
}

/*
  wiz_dir_list_entries - Returns a list of all the direcory entries.
 */
int wiz_dir_list_entries (char *dir, DEntry ***list)
{
  int err = 0;
  int fd;
  char *fn;
  char *buf, *f;
  char *end;
  struct stat statbuf;
  wiz_dir_entry *entry = NULL;
  int num_entries = 0;
  int i;
  int clear = 0;

  err = wiz_uuidtofn(base, dir, &fn);
  if (err)
     return err;

  fd = open(fn, O_RDWR);
  if (fd < 0)
     return -errno;

  err = fstat (fd, &statbuf);
  if (err < 0)
    {
      err = -errno;
      goto out;
    }

  buf = f = mmap(0, statbuf.st_size, PROT_READ | PROT_WRITE,
                 MAP_SHARED, fd, 0);
  if ((int) f == -1)
    {
      err = -EIO;
      goto out;
    }

  end = f + statbuf.st_size;

  while (f < end)
    {
      entry = (wiz_dir_entry*) f;
      num_entries++;
      f += ntohs(entry->rec_len);
    }

  *list = NULL;
  *list = calloc(num_entries + 1, sizeof(DEntry*));
  if (*list == NULL)
    {
      err = -ENOMEM;
      goto out;
    }

  /* Reset to start of file */
  f = buf;
  i = 0;
  while (f < end && i < num_entries)
    {
      DEntry *new = NULL;

      entry = (wiz_dir_entry*) f;
      new = malloc(sizeof(DEntry));
      if (new == NULL)
        {
          err = -ENOMEM;
          clear = 1;
          goto out;
        }
      new->name = NULL;
      new->name = malloc(sizeof(entry->name_len) + 1);
      if (new->name == NULL)
        {
          err = -ENOMEM;
          clear = 1;
          goto out;
        }

      new->name_len = entry->name_len;
      new->file_type = entry->file_type;
      memcpy(new->name, entry->name, entry->name_len);
      new->name[(int) entry->name_len] = '\0';
      memcpy(new->f_uuid, entry->f_uuid, sizeof(uuid_t));
      (*list)[i] = new;

      f += ntohs(entry->rec_len);
      i++;
    }

out:
  if (clear)
    {
      int i;
      for (i=0; (*list)[i]!=NULL; i++)
        {
          if (((*list)[i])->name != NULL)
            {
              free(((*list)[i])->name);
            }
          free((*list)[i]);
        }
      free(*list);
    }
  close(fd);
  free(fn);
  return err;
}
