using Wiz.Private;

namespace Wiz {

	public class CommitBuilder {
		private Bit bit;
		private CommitStore commit_store;
		private BlobStore blob_store;
		private Commit new_commit;
		private string _blob;

		public CommitBuilder(Bit bit) {
			this.bit = bit;
			this.commit_store = bit.commits;
			this.blob_store = bit.blobs;

			this.new_commit = new Commit();
			this.new_commit.timestamp = 0;
			this.new_commit.committer = "";
		}

		public void add_parent(Version parent) {
			this.new_commit.parents.append(parent.version_uuid);
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

		public Version commit() {
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

			this.commit_store.store_commit(this.new_commit);

			return this.bit.open_version(this.new_commit.uuid);
		}

	}

}