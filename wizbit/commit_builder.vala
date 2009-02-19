
namespace Wiz {

	public class CommitBuilder {
		private CommitStore commit_store;
		private Commit new_commit;

		public CommitBuilder(CommitStore commit_store) {
			this.commit_store = commit_store;
			this.new_commit = new Commit();
		}

		public void add_parent(string parent) {
			this.new_commit.parents.append(parent);
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
			this.commit_store.store_commit(new_commit);
		}

	}

}
