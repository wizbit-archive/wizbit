/*
  WizBit : Git based fuse file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#ifndef __WIZ_FS_H__
#define __WIZ_FS_H__

#include <inttypes.h>
#include <uuid/uuid.h>

/* wiz_dir_entry - The on disk format of a directory entry*/
typedef struct
{
  uuid_t f_uuid;
  uint16_t rec_len;
  char name_len;
  char file_type;
  char name [];
} wiz_dir_entry;

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
fntouuid (char* fname, uuid_t uuid);

int
uuidtofn (uuid_t uuid, char **fname);

#endif  /* __WIZ_FS_H__ */
