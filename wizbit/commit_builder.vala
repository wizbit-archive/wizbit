
namespace Wiz {

	public class CommitBuilder {
		private CommitStore commit_store;
		private BlobStore blob_store;
		private Commit new_commit;
		private string _blob;

		public CommitBuilder(CommitStore commit_store, BlobStore blob_store) {
			this.commit_store = commit_store;
			this.new_commit = new Commit();
		}

		public void add_parent(string parent) {
			this.new_commit.parents.append(parent);
		}

		public string blob {
			set {
				this._blob = value;
			}
		}

		public int timestamp {
			set {
				this.new_commit.timestamp = value;
			}
		}

		public string committer {
			set {
				this.new_commit.committer = value;
			}
		}

		public void commit() {
			// The next 4 lines are deprecated and here only to ease transition
			// of wiz-fuse, sync and our tests
			var blob = new Blob(this.blob_store);
			blob.set_contents((void *)this._blob, this._blob.len());
			blob.write();
			this.new_commit.blob = blob.uuid;

			if (this.new_commit.committer == "") {
				// Retrieve from (getpwname)->pw_gecos, env or something
				this.new_commit.committer = "John Carr <john.carr@unrouted.co.uk>";
			}

			if (this.new_commit.timestamp == 0) {
				this.new_commit.timestamp = (int) time_t();
				var tv = TimeVal();
				tv.get_current_time();
				this.new_commit.timestamp2 = (int) tv.tv_usec;
			}

			this.commit_store.store_commit(new_commit);
		}

	}

}
