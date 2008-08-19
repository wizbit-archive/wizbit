/* 
  ref-store class

  Responsible for storing all references to file stores.
  Each file store has a vector of references that are the
  'leaves' or 'tips' of its commit tree.

  One of these 'tips' is designated the 'head'. This is the
  currently checked out version of the file-store.
 
  There are a large amount of concurrency and transactional
  issues in this class.
  
  A single object will be used from multiple threads to update
  references.
*/

#ifndef WIZ_REF_STORE_H
#define WIZ_REF_STORE_H

#include <uuid/uuid.h>

#include <wizbit/error.h>

typedef char wiz_reference[20];

typedef struct wiz_ref_store_t wiz_ref_store;

typedef struct wiz_ref_transaction_t wiz_ref_transaction;

typedef struct wiz_ref_iterator_t wiz_ref_iterator;

/* 
  wiz_ref_store_create
 
  Constructor for a ref store that creates the persistant
  data required for the reference store at the directory
  provided.
  
  An error will be returned if the directory already
  contains data for a reference store, or there are any conflicts.
*/
wiz_ref_store *wiz_ref_store_create(char *dname, wiz_error **err);

/* 
  wiz_ref_store_access
 
  Constructor for a ref store that accesses a
  previously created reference store.

  An error will be returned if the directory does not already
  contain data for a reference store.
*/
wiz_ref_store *wiz_ref_store_access(char *dname, wiz_error **err);

/*
  wiz_ref_store_free

  Frees all resources associated with the reference store object.
*/
void wiz_ref_store_free(wiz_ref_store *rstore);

/* 
  wiz_ref_store_add_ref

  Adds a reference for the file store identified by id.
  The reference is set to the sha1 of 0000-0000-0000-0000
  signifying an empty file.
*/
void wiz_ref_store_add_ref(wiz_ref_store *rstore,
			   uuid_t id,
			   wiz_error **err);

/*
 * wiz_ref_store_update_ref
 *
 * Updates the references associated with a single file id.
 */
void wiz_ref_store_update_ref(wiz_ref_store *rstore,
			      uuid_t id,
			      wiz_reference *tips,
			      wiz_reference ftip,
			      wiz_error **err);

/*
  wiz_ref_store_do_transaction

  Multiple reference updates must sometimes take place withing a
  transaction.

  This is to enable things such as the moving of files.
  Each file store may contain a directory listing and a change to one 
  file store without the other may result in a loss or duplication 
  of the file entry.
*/
wiz_ref_transaction *wiz_ref_store_create_transaction(wiz_ref_store *rstore,
						      wiz_error **err);

/*
  wiz_ref_store_transaction_add

  Adds a reference update to take place during the transaction.
*/
void wiz_ref_store_transaction_add(wiz_ref_transaction *trs,
				   uuid_t id,
				   wiz_reference *tips,
				   wiz_reference ftip,
				   wiz_error **err);

/*
  wiz_ref_store_transaction_commit

  Commits a transaction. Either all the updates added will take
  place or none of them.
*/
void wiz_ref_store_transaction_commit(wiz_ref_transaction *trs,
				      wiz_error **err);

/*
  wiz_ref_store_transaction_free

  Frees all resources associated with the transaction.
*/
void wiz_ref_store_transaction_free(wiz_ref_transaction *trs);

/*
  wiz_ref_store_get_refs

  Accesses all the references of a single file-id.

  @rstore: Refs store object
  @id: File id of references requested
  @refs: Pointer to an array of references, the return slot
  @len: Length of returned array.
*/
void wiz_ref_store_get_refs(wiz_ref_store *rstore,
			    uuid_t id,
			    wiz_ref_iterator **iter,
			    wiz_error **err);

/*
  wiz_ref_store_get_tips

  Accesses all the tips of the file-id.
  This is the references not including the head reference. 

  @rstore: Refs store object
  @id: File id of references requested
  @refs: Pointer to an array of references, the return slot
  @len: Length of returned array.
*/
void wiz_ref_store_get_tips(wiz_ref_store *rstore,
			    uuid_t id,
			    wiz_ref_iterator **iter,
			    wiz_error **err);

/*
  wiz_ref_store_get_head

  Returns the head reference of a particular file-id.
*/
wiz_reference *wiz_ref_store_get_head(wiz_ref_store *rstore,
				      uuid_t id,
				      wiz_error **err);

/*
  wiz_ref_store_iterator_next

  Returns the next reference in the sequence or NULL
  if there are no more references.
*/
wiz_reference *wiz_ref_store_iterator_next(wiz_ref_iterator *iter);

/*
  wiz_ref_store_iterator_free

  Frees all resources associated with the iterator.
*/
void wiz_ref_store_iterator_free(wiz_ref_iterator *iter);

#endif /* WIZ_REF_STORE_H */
