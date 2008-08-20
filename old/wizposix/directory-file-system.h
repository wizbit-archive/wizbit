/*
  WizBit : Git based file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#ifndef __WIZ_DIRECTORY_FILE_SYSTEM_H__
#define __WIZ_DIRECTORY_FILE_SYSTEM_H__

#include <uuid/uuid.h>

int
wiz_create_fs (char* base);

int
wiz_lookup (char* base, char *path, DEntry **entry);

#endif  /* __WIZ_DIRECTORY_FILE_SYSTEM_H__ */
