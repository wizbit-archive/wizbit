/*
  WizBit : Git based fuse file system
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

#include <wiz-fs.h>

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
make_empty (uuid_t dir, uuid_t parent)
{
  char *fn;
  int err;
  int rec_len;
  wiz_dir_entry *entry;

  FILE *f;

  err = uuidtofn(dir, &fn);
  if (err)
     return err;

  f = fopen(fn, "w");

  entry = (wiz_dir_entry*) malloc(sizeof(wiz_dir_entry) + 2);
  entry->file_type = WIZ_FT_DIR;

  rec_len = sizeof(wiz_dir_entry) + 1;
  memcpy(entry->f_uuid, dir, sizeof(uuid_t));
  entry->name_len = 1;
  entry->rec_len = htons(rec_len);
  memcpy(entry->name, ".", entry->name_len);
  fwrite(entry, rec_len, 1, f);

  rec_len = sizeof(wiz_dir_entry) + 2;
  memcpy(entry->f_uuid, parent, sizeof(uuid_t));
  entry->name_len = 2;
  entry->rec_len = htons(rec_len);
  memcpy(entry->name, "..", entry->name_len);
  fwrite(entry, rec_len, 1, f);

  fclose(f);
  free(fn);
  return 0;
}

/*
  add_link - Adds a directory entry to the given directory.

  @dir: Directory to add link to.
  @de: Entry to place into the directory.
 */
int
add_link (uuid_t dir, DEntry* de)
{
  int err = 0;
  int fd;
  char *fn;
  char *buf;
  char *f;
  char *end;
  struct stat statbuf;
  int rec_len;
  int prev_rec_len;
  wiz_dir_entry *entry;
  wiz_dir_entry *new_entry;

  err = uuidtofn(dir, &fn);
  if (err)
     return err;

  fd = open(fn, O_RDWR);
  if (fd < 0)
     return -EIO;

  err = fstat (fd, &statbuf);
  if (err < 0)
    {
      err = -EIO;
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
      if (room_left > rec_len)
        {

           prev_rec_len = sizeof(wiz_dir_entry) + entry->name_len;
           new_entry = (wiz_dir_entry*) f + prev_rec_len;
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
      err = -EIO;
      goto out;
    }
  /* write a dummy byte at the last location */
  if (write (fd, "", 1) != 1)
    {
      err = -EIO;
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
remove_link (uuid_t dir, DEntry *de)
{
  int err = 0;
  int fd;
  char *fn;
  char *buf, *f;
  char *end;
  struct stat statbuf;
  wiz_dir_entry *entry = NULL;
  wiz_dir_entry *prev_entry = NULL;

  err = uuidtofn(dir, &fn);
  if (err)
     return err;

  fd = open(fn, O_RDWR);
  if (fd < 0)
     return -EIO;

  err = fstat (fd, &statbuf);
  if (err < 0)
    {
      err = -EIO;
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
             }
           goto out;
        }
      f += ntohs(entry->rec_len);
    }

  /*
    If we have reached this point then no record was
    found that matches.
   */
  /* TODO what error if any is returned when file not found.*/
  err = -EIO;

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
int
set_link (uuid_t dir, DEntry *de, uuid_t file)
{
  int err = 0;
  int fd;
  char *fn;
  char *buf, *f;
  char *end;
  struct stat statbuf;
  wiz_dir_entry *entry = NULL;

  err = uuidtofn(dir, &fn);
  if (err)
     return err;

  fd = open(fn, O_RDWR);
  if (fd < 0)
     return -EIO;

  err = fstat (fd, &statbuf);
  if (err < 0)
    {
      err = -EIO;
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
  /* TODO what error if any is returned when file not found.*/
  err = -EIO;

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
int
find_entry (uuid_t dir, DEntry *de, DEntry **res)
{
  int err = 0;
  int fd;
  char *fn;
  char *buf, *f;
  char *end;
  struct stat statbuf;
  wiz_dir_entry *entry = NULL;

  err = uuidtofn(dir, &fn);
  if (err)
     return err;

  fd = open(fn, O_RDWR);
  if (fd < 0)
     return -EIO;

  err = fstat (fd, &statbuf);
  if (err < 0)
    {
      err = -EIO;
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
           ((*res)->name)[entry->name_len] = '\0';
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

out:
  close(fd);
  free(fn);
  return err;
}

#if 1
int
print_entries (uuid_t dir)
{
  int err = 0;
  int fd;
  char *fn;
  char *buf, *f;
  char *end;
  struct stat statbuf;
  wiz_dir_entry *entry = NULL;

  err = uuidtofn(dir, &fn);
  if (err)
     return err;
  printf("\n-------------------------------------\n");
  printf("Directory - %s\n\n", fn);

  fd = open(fn, O_RDWR);
  if (fd < 0)
     return -EIO;

  err = fstat (fd, &statbuf);
  if (err < 0)
    {
      err = -EIO;
      goto out;
    }
  printf("Size - %d\n", statbuf.st_size);

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
      char *uuids;
      char *name;

      err = uuidtofn(entry->f_uuid, &uuids);
      if (err)
          goto out;
      name = malloc(entry->name_len + 1);
      memcpy(name, entry->name, entry->name_len);
      name[entry->name_len] = '\0';
      printf("uuid: %s\nname_len: %d\nfile_type: %d\nname: %s\n\n",
             uuids,
             entry->name_len,
             entry->file_type,
             name);
      free(uuids);
      free(name);
      f += ntohs(entry->rec_len);
    }

out:
  close(fd);
  free(fn);
  return err;
}
#endif
