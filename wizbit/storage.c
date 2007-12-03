#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <git/cache.h>
#include <git/builtin.h>
#include <git/cache.h>
#include <uuid/uuid.h>

#include "storage.h"

extern char *work_dir;

static void
check_symlinks (char *path, int len)
{
	struct stat st1;
	path[len] = 0;
	strcpy(path + len, "/tXXXXXX");
	printf("making temp %s\n",path);
	if (!close(xmkstemp(path)) &&
	    !unlink(path) &&
	    !symlink("testing", path) &&
	    !lstat(path, &st1) &&
	    S_ISLNK(st1.st_mode))
		unlink(path); /* good */
	else
		git_config_set("core.symlinks", "false");
}

int
create_file_store (FileId *new_fileid /*out*/ )
{
	char *path;
	char *sha1_dir;
	int len;

	uuid_generate (*new_fileid);

	len = strlen (work_dir);
	path = xmalloc (len + 1 + FILEID_LEN_AS_STRING + strlen("/refs/heads"));

	memcpy (path, work_dir, len);
	path [len++] = '/';

	uuid_unparse (*new_fileid, path + len);
	len += FILEID_LEN_AS_STRING;

	mkdir (path, 0700);

	setenv("GIT_DIR", path, 1);

	strcpy (path + len, "/refs");
	mkdir (path, 0700);
	strcpy (path + len, "/refs/heads");
	mkdir (path, 0700);
	strcpy (path + len, "/refs/tags");
	mkdir (path, 0700);

	if (create_symref ("HEAD", "refs/heads/master", NULL) < 0) 
		return 0;

	git_config_set ("core.bare", "true");
	check_symlinks (path, len);

	sha1_dir = get_object_directory();

	/*
	 * And set up the object store.
	 */
	sha1_dir = get_object_directory();
	len = strlen(sha1_dir);
	path = xmalloc(len + 40);
	memcpy(path, sha1_dir, len);

	mkdir(sha1_dir, 0700);
	strcpy(path+len, "/pack");
	mkdir(path, 0700);
	strcpy(path+len, "/info");
	mkdir(path, 0700);

	return 1;
}


