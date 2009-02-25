using GLib;
using Wiz.Private;

namespace Wiz {
	/**
	 * WizCommit:
	 * The WizCommit object represents a point in history, it allows the developer
	 * to access the parents and children of a version as well as gain access to
	 * the blob itself.
	 */
	public class Commit : GLib.Object {
		public Bit bit { get; construct; }
		public string version_uuid { get; construct; }

		private Wiz.Private.Commit commit;

		public Commit(Bit bit, string version_uuid) {
			this.bit = bit;
			this.version_uuid = version_uuid;

			this.commit = this.bit.commits.lookup_commit(this.version_uuid);
		}

		/**
		 * wiz_commit_get_blob_id:
		 * @returns: The sha of the blob associated with this version.
		 *
		 * Deprecated: 0.1
		 */
		internal string blob_id {
			get {
				return this.commit.hash;
			}
		}

		/**
		 * wiz_commit_get_committer:
		 * @returns: The name of person who made this commit
		 */
		public string committer {
			get {
				return this.commit.committer;
			}
		}

		/**
		 * wiz_commit_get_timestamp:
		 * @returns: The timestamp
		 */
		public int timestamp {
			get {
				return this.commit.timestamp;
			}
		}

		/**
		 * wiz_commit_get_file:
		 * @returns: The blob
		 */
		public File file {
			owned get {
				return new File(this.blob_id);
			}
		}

		/**
		 * wiz_commit_get_previous:
		 * @returns: The previous commit along the mainline
		 */
		public Commit? previous {
			owned get {
				var v = this.bit.commits.get_backward(this.version_uuid);
				if (v == null)
					return null;
				return new Commit(this.bit, v);
			}
		}

		/**
		 * wiz_commit_get_next:
		 * @returns: The next commit along the mainline
		 */
		public Commit? next {
			owned get {
				var v = this.bit.commits.get_forward(this.version_uuid);
				if (v == null)
					return null;
				return new Commit(this.bit, v);
			}
		}

		public List<Commit> parents {
			owned get {
				var parents = new List<Commit>();
				foreach (var p in this.bit.commits.get_backwards(this.version_uuid))
					parents.append(new Commit(this.bit, p));
				return parents;
			}
		}

		public List<Commit> children {
			owned get {
				var children = new List<Commit>();
				foreach (var c in this.bit.commits.get_forwards(this.version_uuid))
					children.append(new Commit(this.bit, c));
				return children;
			}
		}

		/**
		 * wiz_commit_get_commit_builder:
		 * @returns: A new commit builder object
		 */
		public CommitBuilder get_commit_builder() {
			var cb = this.bit.get_commit_builder();
			cb.add_parent(this);
			return cb;
		}
	}
}
