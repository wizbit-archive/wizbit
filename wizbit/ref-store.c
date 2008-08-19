#include <sqlite3.h>

#include "path.h"
#include "ref-store.h"

#define DATABASE_NAME "wizbit_references.db"

struct wiz_ref_store_t {
	char *filename;
};

struct wiz_ref_transaction_t {
	wiz_ref_store *store;
	wiz_ref_update *updates;
};

#define RETURN_VAL_IF_ERR(vAL, rC, eRR, fMT, args...)		\
	if (rC != SQLITE_OK){					\
		wiz_runtime_error(eRR, WIZ_ERROR_REFERENCE_UPDATE, fMT, ## args);\
		return vAL;					\
	}

/*----------------------------------------------------------------------------*/

#define CREATE_UUID_TABLE "create table filestore(uuid varchar(16) primary key);"

wiz_ref_store *wiz_ref_store_create(char *dname, wiz_err **err){
	sqlite3 *db;
	sqlite3_stmt *stmt;
	int rc;

	char *dbpath;

	dbpath = wiz_path_join(dname, DATABASE_NAME);

	rc = sqlite3_open_v2(dbpath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
	free(dbpath);
	RETURN_VAL_IF_ERR(NULL, rc, err, "Reference DB could not be created");

	rc = sqlite3_prepare_v2(db, CREATE_UUID_TABLE, -1, &stmt, NULL);
	RETURN_VAL_IF_ERR(NULL, rc, err, "ID table of ref DB could not be created");
}

/*----------------------------------------------------------------------------*/

wiz_ref_store *wiz_ref_store_access(char *dname, wiz_err **err){
	;
}
