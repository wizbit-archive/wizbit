#include <sys/stat.h>
#include <uuid/uuid.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "wiz_fs.h"

static inline wiz_match (int len, char *const name, struct wiz_dir_entry *de) 
{
	if (len != ntohs(de->name_len))
		return 0;
	if (!de->uuid)
		return 0;
	return !memcmp(name, de->name, len);
}

static int wiz_insert_dirent(FILE *file, uuid_t fsuid, int ftype, char* name)
{
	int nlen;
	uint16_t ent;

	nlen = strlen(name) + 1;

	fwrite(fsuid, 1, 16, file);
	ent = htons(nlen + WIZ_DIRENT_FIXED);
	fwrite(&ent, sizeof(uint16_t), 1, file );
	ent = htons(nlen);
	fwrite(&ent, sizeof(uint16_t), 1, file);
	ent = htons(ftype);
	fwrite(&ent, sizeof(uint16_t), 1, file);
	fwrite(name, 1, nlen, file);

	return  nlen + WIZ_DIRENT_FIXED;
}

int wiz_add_entry(char* fstore, uuid_t uuide, int ftype, char* name)
{
	FILE *file;
	char *buf, *or, *insp;
	struct stat statbuf;
	int ctype;

	file = fopen(fstore, "rb+");

	if (fstat(fileno(file), &statbuf))
		return -errno;

	if(!(buf = or = malloc(statbuf.st_size)))
		return -1;

	fread(buf, 1, statbuf.st_size, file);

	do {
		insp = buf;
		ctype = ntohs(((struct wiz_dir_entry*)buf)->file_type);
		buf += ntohs(((struct wiz_dir_entry*)buf)->rec_len);
	} while (ctype != WIZ_FT_UNKNOWN);

	if (fseek(file, -ntohs(((struct wiz_dir_entry*)insp)->rec_len), SEEK_CUR))
		return -errno;

	wiz_insert_dirent(file, uuide, ftype, name);
	wiz_insert_dirent(file, "", WIZ_FT_UNKNOWN, "");

	fclose(file);

	return 0;
}	

int wiz_find_entry(char *fstore, char *const name, uuid_t fsuid)
{
	FILE *file;
	char *buf, *or, *insp;
	struct stat statbuf;
	int ctype;

	file = fopen(fstore, "rb+");

	if (fstat(fileno(file), &statbuf))
		return -errno;

	if(!(buf = or = malloc(statbuf.st_size)))
		return -1;

	fread(buf, 1, statbuf.st_size, file);

	do {
		if (wiz_match(strlen(name), name, (struct wiz_dir_entry*)buf)) {
			memcpy(fsuid, ((struct wiz_dir_entry*)buf)->uuid, 16);
			return 0;
		}
		buf += ntohs(((struct wiz_dir_entry*)buf)->rec_len);
	} while (ctype != WIZ_FT_UNKNOWN);

	fclose(file);
	return -1;
}

int wiz_init_dir(char *fstore, uuid_t fsuid, uuid_t parent)
{
	FILE *file;

	file = fopen(fstore, "w");

	wiz_insert_dirent(file, fsuid, WIZ_FT_DIR, ".");
	wiz_insert_dirent(file, parent, WIZ_FT_DIR, "..");
	wiz_insert_dirent(file, "", WIZ_FT_UNKNOWN, "");

	fclose(file);

	return 0;
}
