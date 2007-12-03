#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

#include <git/strbuf.h>
#include <uuid/uuid.h>

#include "wizbit/storage.h"

char *work_dir = "/tmp/wizbittest";

int main()
{
	FileId fileid;
	char fid[FILEID_LEN_AS_STRING];
	char path;
	struct stat st;
	struct strbuf buf;

	mkdir (work_dir,0700);
	create_file_store(&fileid);

	fileid_to_string(fileid, fid);
	printf("created file id %s\n", fid);

	strbuf_init(&buf, 100);
	strbuf_addstr(&buf, work_dir);
	strbuf_addstr(&buf, "/");
	strbuf_addstr(&buf, fid);
	strbuf_addstr(&buf, "/objects/info");

	if (stat(buf.buf, &st) < 0) {
		printf("%s not found: %s\n", buf.buf, strerror(errno));
		exit(1);
	}
	exit (0);
}

int
commit_
