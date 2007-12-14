#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include <uuid/uuid.h>

#include "wiz_fs.h"

inline int wiz_fstouuid(char* fstore, uuid_t uuid)
{
	char uuids[FSTORE_NAME_SIZE];

	memcpy(uuids, fstore, UUID_SIZE);
	uuids[UUID_SIZE-1] = '\0';

	uuid_parse(uuids, uuid);
}

inline int wiz_uuidtofs_data(uuid_t uuid, char *fstore)
{
	uuid_unparse_lower(uuid, fstore);
	memcpy(&fstore[UUID_SIZE], ".data", EXTENSION_SIZE);
}

inline int wiz_uuidtofs_file(uuid_t uuid, char *fstore)
{
	uuid_unparse_lower(uuid, fstore);
	memcpy(&fstore[UUID_SIZE], ".file", EXTENSION_SIZE);
}

int wiz_fstore_mk(mode_t mode, uuid_t made)
{
	int res;
	char fpath[FSTORE_NAME_SIZE];
	char dpath[FSTORE_NAME_SIZE];
	uuid_t fsuid;

	struct wiz_mdata mdata;

	if (S_ISFIFO(mode)) {
		return -ENOTSUP;
	}

	uuid_generate(fsuid);

	wiz_uuidtofs_file(fsuid, fpath);
	wiz_uuidtofs_data(fsuid, dpath);

	res = open(dpath, O_CREAT | O_EXCL | O_WRONLY, mode);
	if (res < 0) 
		return -errno;
	if (S_ISREG(mode)) {
		mdata.file_type = WIZ_FT_REG_FILE;
	} else if (S_ISDIR(mode)) {
		mdata.file_type = WIZ_FT_DIR;
	} else {
		close(res);
		return -ENOTSUP;
	}
       	write(res, &mdata, sizeof(struct wiz_mdata));
	res = close(res);
	if (res < 0) 
		return -errno;

	res = open(fpath, O_CREAT | O_EXCL | O_WRONLY, mode);
	if (res < 0) 
		return -errno;
	res = close(res);
	if (res < 0) 
		return -errno;
	/* Return the new fstore */
	memcpy(made, fsuid, 16);
	return 0;
}
