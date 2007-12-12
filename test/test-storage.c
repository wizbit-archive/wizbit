#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>

#include <string.h>
#include <errno.h>

#include <git/strbuf.h>
#include <uuid/uuid.h>

#include "wizbit/storage.h"

char *work_dir = "/tmp/wizbittest";


static void
test_create_file_store()
{
	FileId fileid;
	char fid[FILEID_LEN_AS_STRING+1];
	struct stat st;
	struct strbuf buf;

	printf("%s\n", __func__);
	if (create_file_store(fileid)) {
		printf("failed to create file store\n");
		exit(1);
	}

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

}

static void
test_update_file_store()
{
	FileId fileid;
	char fid[FILEID_LEN_AS_STRING+1];
	struct strbuf buf;
	int fd, i;

	printf("%s\n", __func__);
	if (create_file_store(fileid))
		exit(1);

	fileid_to_string(fileid, fid);
	printf("created file id %s\n", fid);
	strbuf_init(&buf, 100);
	strbuf_addstr(&buf, work_dir);
	strbuf_addstr(&buf, "/");
	strbuf_addstr(&buf, fid);
	strbuf_addstr(&buf, ".file");

	printf("writing 4096 consecutive ints to %s\n",buf.buf);
	fd = open(buf.buf, O_WRONLY | O_CREAT, 0666);
	for (i=0; i < 4096; i++)
		write(fd, &i, sizeof(i));
	close(fd);

	update_file_store(fileid, 1, 0);
}

int main()
{
	system ("rm -rf /tmp/wizbittest");
	mkdir (work_dir,0700);
	chdir (work_dir);

	test_create_file_store();
	test_create_file_store();
	test_update_file_store();
	return 0;
}

