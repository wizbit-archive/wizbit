#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <git/builtin.h>
#include <git/cache.h>
#include <git/cache-tree.h>
#include <git/refs.h>
#include <git/tree-walk.h>
#include <git/commit.h>
#include <uuid/uuid.h>

#include "storage.h"

typedef unsigned char sha1[20];

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
create_file_store (FileId new_fileid /*out*/ )
{
	char *path;
	char *sha1_dir;
	int len;

	uuid_generate (new_fileid);

	len = strlen (work_dir);
	path = malloc (len + 1 + FILEID_LEN_AS_STRING + strlen("/refs/heads"));
	
	if (path == NULL) return ENOMEM;

	memcpy (path, work_dir, len);
	path [len++] = '/';

	uuid_unparse (new_fileid, path + len);
	len += FILEID_LEN_AS_STRING;

	mkdir (path, 0700);

	set_git_dir(path);

	printf ("GIT_DIR = %s\n", getenv("GIT_DIR"));

	strcpy (path + len, "/refs");
	mkdir (path, 0700);
	strcpy (path + len, "/refs/heads");
	mkdir (path, 0700);
	strcpy (path + len, "/refs/tags");
	mkdir (path, 0700);

	if (create_symref ("HEAD", "refs/heads/master", NULL) < 0) {
		printf("failed to create HEAD ref\n");
		return -1;
	}

	git_config_set ("core.bare", "true");
	check_symlinks (path, len);

	free(path);

	sha1_dir = get_object_directory();

	/*
	 * And set up the object store.
	 */
	sha1_dir = get_object_directory();
	len = strlen(sha1_dir);

	path = malloc(len + 40);
	if (path == NULL) {
		printf ("failed to allocate for sha1_dir\n");
		return ENOMEM;
	}

	memcpy(path, sha1_dir, len);

	mkdir(sha1_dir, 0700);
	strcpy(path+len, "/pack");
	mkdir(path, 0700);
	strcpy(path+len, "/info");
	mkdir(path, 0700);

	free(path);
	return 0;
}

static int
add_tree_entry_to_index(struct index_state *index, sha1 treeish, const char* name, int namelen)
{
	unsigned int mode, size;
	struct cache_entry *ce;

	size = cache_entry_size(namelen);
	ce = calloc (1, size);
	if (!ce)
		return ENOMEM;

	if (get_tree_entry(treeish, name, ce->sha1, &mode) == 0) {
		printf("Resolved tree entry to %s\n", sha1_to_hex(ce->sha1));
		memcpy(ce->name, name, namelen);
		ce->ce_flags = htons(namelen);
		ce->ce_mode = mode;
		if (add_index_entry(index, ce, ADD_CACHE_OK_TO_ADD|ADD_CACHE_OK_TO_REPLACE))
			return ENOMEM;
	} else {
		free(ce);
	}
	return 0;
}

int
update_file_store(const FileId fileid, int file, int meta)
{
	struct cache_tree *ctree;
	struct tree *tree;
	struct tree_desc desc;
	char *path;
	struct index_state index;
	sha1 treeish, commit;
	struct strbuf buffer;
	const int namelen = FILEID_LEN_AS_STRING + 5; /* uuid followed by 5 char suffix */
	int first_commit = 0;

	ctree = cache_tree();
	memset (&index, 0, sizeof(index));

	if (chdir(work_dir))
		return ENOENT;

	path = malloc (namelen + 1);
	if (path == NULL) return ENOMEM;

	uuid_unparse (fileid, path);

	if (read_ref("HEAD", treeish)) {
		printf("first commit, it seems\n");
		first_commit = 1;
	}

	strcpy(path + FILEID_LEN_AS_STRING, ".file");

	printf("%s\n", path);

	if (file) {
		printf("adding %s to index\n", path);
		add_file_to_index(&index, path, 1);
	} else if (!first_commit) {
		printf("adding tree entry %s on %s to index\n", path, sha1_to_hex(treeish));
		add_tree_entry_to_index (&index, treeish, path, namelen);
	}
	
	strcpy(path + FILEID_LEN_AS_STRING, ".meta");

	if (meta) {
		printf("adding %s to index\n", path);
		add_file_to_index(&index, path, 1);
	} else if (!first_commit) {
		printf("adding tree entry %s on %s to index\n", path, sha1_to_hex(treeish));
		add_tree_entry_to_index (&index, treeish, path, namelen);
	}
	
	if (cache_tree_update(ctree, index.cache, index.cache_nr, 1, 0))
		return -1;

	printf ("Creating commit object\n");

	strbuf_init(&buffer, 8192); /* should avoid reallocs for the headers */
	strbuf_addf(&buffer, "tree %s\n", sha1_to_hex(ctree->sha1));

	if (!first_commit)
		strbuf_addf(&buffer, "parent %s\n", sha1_to_hex(treeish));

	strbuf_addf(&buffer, "author %s\n", git_author_info(1));
	strbuf_addf(&buffer, "committer %s\n", git_committer_info(1));
	strbuf_addch(&buffer, '\n');

	if (write_sha1_file(buffer.buf, buffer.len, commit_type, commit)) {
		printf ("Error creating commit\n");
		return -1;
	}
	printf("created commit %s\n", sha1_to_hex(commit));

	printf ("updating HEAD reference\n");
	update_ref(NULL, "HEAD", commit, first_commit ? NULL : treeish, 0, MSG_ON_ERR);
}
