/*
  The fake repository is going to do the following:

  Create the directories:

  .wiz/objects/
  .wiz/stores/

  All file stores created will create a file in
  
  .wiz/objects/data/0000-0000-0000-0000
  .wiz/objects/meta/0000-0000-0000-0000

  When accessing a file store the sha will be ignored
  (There is no versioning)

  The files will be copied from .wiz/objects to
  .wiz/stores.

  When a file store is committed it will be copied
  back to the object directories, over the top of the
  old file "committing it".
*/

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#include "xmalloc.h"
#include "path.h"
#include "repository.h"

#define DIR_MODE 0755

struct wiz_repository_t {
	char *wizpath;
	char *object_data;
	char *object_meta;
	char *store_data;
	char *store_meta;
};

struct wiz_file_store_t {
	wiz_repository *repo;
	uuid_t f_uuid;
	/* TODO this needs to be guarded. We need a std ref object */
	int ref;
};

/*----------------------------------------------------------------------------*/

static char *file_store_data_source(wiz_file_store *store)
{
	char *uuid_str;
	char *res;

	uuid_unparse_lower(store->f_uuid, uuid_str);	
	res = wiz_path_join(store->repo->object_data, uuid_str);
	free(uuid_str);
	return res;
}

/*----------------------------------------------------------------------------*/

static char *file_store_meta_source(wiz_file_store *store)
{
	char *uuid_str;
	char *res;

	uuid_unparse_lower(store->f_uuid, uuid_str);	
	res = wiz_path_join(store->repo->object_meta, uuid_str);
	free(uuid_str);
	return res;
}

/*----------------------------------------------------------------------------*/

static char *file_store_data_dest(wiz_file_store *store)
{
	char *uuid_str;
	char *res;

	uuid_unparse_lower(store->f_uuid, uuid_str);	
	res = wiz_path_join(store->repo->store_data, uuid_str);
	free(uuid_str);
	return res;
}

/*----------------------------------------------------------------------------*/

static char *file_store_meta_dest(wiz_file_store *store)
{
	char *uuid_str;
	char *res;

	uuid_unparse_lower(store->f_uuid, uuid_str);	
	res = wiz_path_join(store->repo->store_meta, uuid_str);
	free(uuid_str);
	return res;
}

/*----------------------------------------------------------------------------*/

static void file_copy(char *input, char* output, mode_t mode, wiz_error **err)
{
	int ifd, ofd;
	size_t filesize;
	void *source, *target;

	if((ifd = open(input, O_RDONLY)) == -1) {
		wiz_runtime_err(err, "Error copying file %s to %s", input, output);
		return;
	}

	if((ofd = open(output, O_RDWR|O_CREAT|O_TRUNC, mode)) == -1) {
		wiz_runtime_err(err, "Error copying file %s to %s", input, output);
		close(ifd);
		return;
	}

	filesize = lseek(ifd, 0, SEEK_END);
	lseek(ofd, filesize - 1, SEEK_SET);
	write(ofd, '\0', 1);

	if((source = mmap(0, filesize, PROT_READ, MAP_SHARED, ifd, 0)) == (void *) -1) {
		wiz_runtime_err(err, "Error copying file %s to %s", input, output);
		goto out;
	}

	if((target = mmap(0, filesize, PROT_WRITE, MAP_SHARED, ofd, 0)) == (void *) -1) {
		wiz_runtime_err(err, "Error copying file %s to %s", input, output);
		goto out;
	}

	memcpy(target, source, filesize);

	munmap(source, filesize);
	munmap(target, filesize);

out:
	close(ifd);
	close(ofd);
	return;
}


/* Repository operations                                                      */
/*----------------------------------------------------------------------------*/

wiz_repository *wiz_repository_create(char *dpath, wiz_error **err)
{
	wiz_repository *repo;
	char *objects;
	char *stores;
	int perr;

	repo = xmalloc(sizeof(wiz_repository));

	repo->wizpath = wiz_path_join(dpath, ".wiz");	
	objects = wiz_path_join(repo->wizpath, "objects");
	stores = wiz_path_join(repo->wizpath, "stores");
	repo->object_data = wiz_path_join(repo->wizpath, "objects", "data");
	repo->store_data = wiz_path_join(repo->wizpath, "stores", "data");
	repo->object_meta = wiz_path_join(repo->wizpath, "objects", "meta");
	repo->store_meta = wiz_path_join(repo->wizpath, "stores", "meta");

	perr = mkdir(repo->wizpath, DIR_MODE);
	if (perr) {
		wiz_runtime_err(err, "Could not create wizbit directory");
		goto err;
	}

	perr = mkdir(objects, DIR_MODE);
	if (perr) {
		wiz_runtime_err(err, "Could not create objects directory");
		goto err;
	}

	perr = mkdir(stores, DIR_MODE);
	if (perr) {
		wiz_runtime_err(err, "Could not create stores directory");
		goto err;
	}

	perr = mkdir(repo->object_data, DIR_MODE);
	if (perr) {
		wiz_runtime_err(err, "Could not create object data directory");
		goto err;
	}

	perr = mkdir(repo->store_data, DIR_MODE);
	if (perr) {
		wiz_runtime_err(err, "Could not create store data directory");
		goto err;
	}

	perr = mkdir(repo->object_meta, DIR_MODE);
	if (perr) {
		wiz_runtime_err(err, "Could not create object meta data directory");
		goto err;
	}

	perr = mkdir(repo->store_meta, DIR_MODE);
	if (perr) {
		wiz_runtime_err(err, "Could not create store meta data directory");
		goto err;
	}

	free(objects);
	free(stores);
	return repo;
err:
	free(objects);
	free(stores);
	free(repo->wizpath);
	free(repo->object_data);
	free(repo->store_data);
	free(repo->object_meta);
	free(repo->store_meta);
	free(repo);
	return NULL;
}

/*----------------------------------------------------------------------------*/

wiz_repository *wiz_repository_access(char *dpath, wiz_error **err)
{
	wiz_repository *repo;

	repo = xmalloc(sizeof(wiz_repository));

	repo->wizpath = wiz_path_join(dpath, ".wiz");	
	repo->object_data = wiz_path_join(repo->wizpath, "objects", "data");
	repo->store_data = wiz_path_join(repo->wizpath, "stores", "data");
	repo->object_meta = wiz_path_join(repo->wizpath, "objects", "meta");
	repo->store_meta = wiz_path_join(repo->wizpath, "stores", "meta");
}

/*----------------------------------------------------------------------------*/

void wiz_repository_free(wiz_repository *repo)
{
	free(repo->wizpath);
	free(repo->object_data);
	free(repo->store_data);
	free(repo->object_meta);
	free(repo->store_meta);
	free(repo);
}

/*----------------------------------------------------------------------------*/

wiz_file_store *wiz_repository_create_store(wiz_repository* repo, 
					    mode_t mode, 
					    wiz_error **err)
{
	int fd;
	uuid_t n;
	wiz_file_store *store;
	char *data_s;
	char *meta_s;

	store = xmalloc(sizeof(wiz_file_store));
	uuid_generate(n);
	memcpy(store->f_uuid, n, sizeof(uuid_t));
	store->repo = repo;
	store->ref = 1;

	data_s = file_store_data_source(store);
	fd = open(data_s, O_WRONLY | O_CREAT | O_TRUNC, mode);
	if (fd < 0) {
		wiz_runtime_err(err, "Could not create file data");
		return NULL;
	}
	close(fd);
	free(data_s); 

	meta_s = file_store_meta_source(store);
	fd = open(meta_s, O_WRONLY | O_CREAT | O_TRUNC, mode);
	if (fd < 0) {
		wiz_runtime_err(err, "Could not create meta data");
		return NULL;
	}
	close(fd);
	free(meta_s); 

  	return store;
}

/*----------------------------------------------------------------------------*/

wiz_file_store *wiz_repository_access_store(wiz_repository *repo,
					    uuid_t s_uuid,
					    wiz_reference ref,
					    wiz_error **err)
{
	/* Reference ignored completely */
	uuid_t n;
	wiz_file_store *store;

	store = xmalloc(sizeof(wiz_file_store));
	uuid_generate(n);
	memcpy(store->f_uuid, n, sizeof(uuid_t));
	store->repo = repo;

  	return store;
}

/* Repository operations                                                      */
/*----------------------------------------------------------------------------*/

void *wiz_file_store_ref(wiz_file_store *store)
{
	/* FIXME - This is all wrong need to guarantee atomicity */
	store->ref++;
}

/*----------------------------------------------------------------------------*/

void wiz_file_store_unref(wiz_file_store *store)
{
	/* FIXME - This is all wrong need to guarantee atomicity */
	/* TODO - This needs to copy the file back to the objects directory */
	store->ref--;
	if (store->ref == 0)
		free(store);
}

/*----------------------------------------------------------------------------*/

char *wiz_file_store_get_data(wiz_file_store *store)
{
	return file_store_data_dest(store);
}

/*----------------------------------------------------------------------------*/

char *wiz_file_store_get_meta(wiz_file_store *store)
{
	return file_store_meta_dest(store);
}

/*----------------------------------------------------------------------------*/

uuid_t *wiz_file_store_get_uuid(wiz_file_store *store)
{
	return store->f_uuid;
}
