
namespace Wiz {
	/**
	 * WizCommitBuilder:
	 *
	 * The WizCommitBuilder class is responsible for taking blobs and Commits and
	 * entering them into the commit store and blob store where appropriate.
	 * essentially the CommitBuilder acts as a way of pulling together the
	 * disparate elements of a commit and invoking the WizCommitStore correctly.
	 */
	public class CommitBuilder {
		private Bit bit;
		private Wiz.Private.CommitStore commit_store;
		private Wiz.Private.BlobStore blob_store;
		private Wiz.Private.Commit new_commit;
		public Gee.HashMap<string,Wiz.File> streams;

		public CommitBuilder(Bit bit) {
			this.bit = bit;
			this.commit_store = bit.commits;
			this.blob_store = bit.blobs;

			this.new_commit = new Wiz.Private.Commit();
			this.new_commit.timestamp = 0;
			this.new_commit.committer = "";

			this.streams = new Gee.HashMap<string,Wiz.File>(str_hash, str_equal, str_equal);
		}

		/**
		 * wiz_commit_builder_add_parent:
		 * @self:		the commit builder to update
		 * @parent:		the parent commit to add to this commit
		 */
		public void add_parent(Commit parent) {
			this.new_commit.parents.append(parent.version_uuid);
		}

		/**
		 * wiz_commit_builder_add_stream:
		 * @self:		the commit builder to update
		 * @name:		the name of the stream
		 * @stream:		the WizFile stream
		 */
		public void add_stream(string name, Wiz.File stream) {
			this.streams.set(name, stream);
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

		/**
		 * wiz_commit_builder_commit:
		 * @self: The pending commit to write out
		 * @returns: A freshly created, immutable commit object
		 *
		 * make the commit, updates the database and blob store, this is immutable
		 */
		public Commit commit() {
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

			foreach (var key in this.streams.get_keys()) {
				var file = this.streams.get(key);

				// FIXME: Think about interaction between Wiz.Private.Blob and Wiz.File
				// Wiz.File currently assumes things about W.P.Blob, and this will
				// start to smell when we get to GroupCompress
				var blob = new Wiz.Private.Blob(this.blob_store);
				blob.set_contents_from_file(file.get_path());
				blob.write();

				this.new_commit.streams.set(key, blob.uuid);
			}

			this.commit_store.store_commit(this.new_commit);

			return this.bit.open_commit(this.new_commit.uuid);
		}

	}

}
