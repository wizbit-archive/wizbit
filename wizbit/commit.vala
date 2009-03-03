using GLib;
using Wiz.Private;

namespace Wiz {
	/**
	 * WizCommit:
	 *
	 * The WizCommit object represents a point in history, it allows the developer
	 * to access the parents and children of a version as well as gain access to
	 * the blob itself.
	 */
	public class Commit : GLib.Object {
		public Bit bit { get; construct; }
		public string version_uuid { get; construct; }

		private Wiz.Private.Commit commit;
		private Gee.HashMap<string,Wiz.File> _streams;

		public Commit(Bit bit, string version_uuid) {
			this.bit = bit;
			this.version_uuid = version_uuid;

			this.commit = this.bit.commits.lookup_commit(this.version_uuid);

			this._streams = new Gee.HashMap<string,Wiz.File> (str_hash, str_equal, str_equal);
			foreach (var key in this.commit.streams.get_keys()) {
				var file = new File.from_blob(this.bit.blobs.get(this.commit.streams.get(key)));
				this._streams.set(key, file);
			}
		}

		public string committer {
			/**
			 * wiz_commit_get_committer:
			 * @self: The commit to inspect
			 * @returns: The name of person who made this commit
			 */
			get {
				return this.commit.committer;
			}
		}

		public int timestamp {
			/**
			 * wiz_commit_get_timestamp:
			 * @self: The commit to inspect
			 * @returns: The timestamp of the commit
			 */
			get {
				return this.commit.timestamp;
			}
		}

		public Gee.ReadOnlyMap<string,Wiz.File> streams {
			/**
			 * wiz_commit_get_streams:
			 * @self: The commit to inspect
			 * @returns: A readonly only hash map of string:Wiz.File
			 */
			owned get {
				return new Gee.ReadOnlyMap<string,Wiz.File>(this._streams);
			}
		}

		public Commit? previous {
			/**
			 * wiz_commit_get_previous:
			 * @self: The commit to inspect
			 * @returns: The previous commit along the mainline
			 *
			 * This returns a single parent commit. You cannot assume that if you go forwards
			 * and backwards using these methods you will arrive in the same place.
			 */
			owned get {
				var v = this.bit.commits.get_backward(this.version_uuid);
				if (v == null)
					return null;
				return new Commit(this.bit, v);
			}
		}

		public Commit? next {
			/**
			 * wiz_commit_get_next:
			 * @self: The commit to inspect
			 * @returns: The next commit along the mainline
			 *
			 * This returns a single child commit. You cannot assume that if you go forwards
			 * and backwards using these methods you will arrive in the same place.
			 *
			 * Wizbit is based on a directed acylic graph and is optimised for parent relationships
			 * rather than child relationships.
			 */
			owned get {
				var v = this.bit.commits.get_forward(this.version_uuid);
				if (v == null)
					return null;
				return new Commit(this.bit, v);
			}
		}

		public List<Commit> parents {
			/**
			 * wiz_commit_get_parents:
			 * @self: The commit to inspect
			 * @returns: A list of all parents of the current commit
			 *
			 * The parents of a commit are immutable and will not change between calls to this
			 * function.
			 */
			owned get {
				var parents = new List<Commit>();
				foreach (var p in this.bit.commits.get_backwards(this.version_uuid))
					parents.append(new Commit(this.bit, p));
				return parents;
			}
		}

		public List<Commit> children {
			/**
			 * wiz_commit_get_children:
			 * @self: The commit to inspect
			 * @returns: A list of all known children of the commit

			 * Whilst the list of parents is absolute and immutable, you cannot assume
			 * that you know about all children of this commit. Synchronisation will
			 * bring new children.
			 *
			 * Wizbit is based on a directed acylic graph and is optimised for parent relationships
			 * rather than child relationships.
			 */
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
		 *
		 * When getting a commit builder from an existing commit it will automatically
		 * gain that commit as a parent, and a the WizFile objects will be copied accross.
		 */
		public CommitBuilder get_commit_builder() {
			var cb = this.bit.get_commit_builder();
			cb.add_parent(this);
			foreach (var key in this._streams.get_keys())
				cb.streams.set(key, this._streams.get(key));
			return cb;
		}
	}
}
