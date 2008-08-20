/*
  WizBit : Git based file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#ifndef __WIZ_FILE_SYSTEM_H__
#define __WIZ_FILE_SYSTEM_H__

#include <uuid/uuid.h>

enum
{
  WIZ_FT_UNKNOWN = 0,
  WIZ_FT_REG_FILE,
  WIZ_FT_DIR,
  WIZ_FT_SYMLINK,
  WIZ_FT_MAX
};

/* dentry - The in memory representation of a directory entry*/
typedef struct
{
  uuid_t f_uuid;
  int  file_type;
  char name_len;
  char *name;
} DEntry;

/*
  The standard string representation of a uuid as passed by uuid_parse
  is 36 bytes plus trailing '/0'.
 */
#define UUID_STRING_SIZE 37

int
wiz_fntouuid (char* fname, uuid_t uuid);

int
wiz_uuidtofn (char *base, uuid_t uuid, char **fname);

int
wiz_create_dentry(uuid_t uuid,
                  int file_type,
                  char *name,
                  DEntry **entry);

void
wiz_delete_dentry(DEntry *entry);

int
wiz_create_fs (char* base);

int
wiz_lookup (char* base, char *path, DEntry **entry);

int
wiz_create(char *base, char *path, DEntry *entry, mode_t mode);

int
wiz_link(char *base, char *path, DEntry *entry);

int
wiz_unlink(char *base, char *path, DEntry *entry);

int
wiz_mkdir(char *base, char *path, DEntry *entry, mode_t mode);

int
wiz_rmdir(char *base, char *path, DEntry *entry);

int
wiz_rename(char *base, char *oldpath, DEntry *old,
                       char *newpath, DEntry *new);

int
wiz_readdir(char *base, char *path, DEntry ***list);

#if WIZ_DEVEL
int
wiz_print_dir (char *base, char *path);
#endif

#endif  /* __WIZ_FILE_SYSTEM_H__ */
