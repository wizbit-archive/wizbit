#ifndef _WIZBIT_STORAGE_H_
#define _WIZBIT_STORAGE_H_

#define FILEID_LEN_AS_STRING 36

typedef uuid_t FileId;

static inline void fileid_to_string(FileId fid, char *out)
{
	uuid_unparse(fid, out);
}

int create_file_store (FileId *new_fileid /*out*/ );

#endif
