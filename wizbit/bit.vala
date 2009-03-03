using GLib;
using Wiz.Private;

namespace Wiz {
	/**
	 * WizBit:
	 *
	 * A WizBit represents an object with history, for instance a file. The WizBit
	 * is how we obtain information regarding the history of a file or other
	 * piece of data.
	 */
	public class Bit : GLib.Object {
		private string refs_path;
		private string objects_path;

		internal BlobStore blobs;
		public CommitStore commits;

		public string store_path { private get; construct; }

		/**
		 * wiz_bit_get_uuid:
		 * @self: The bit to get the uuid of
		 * @returns: The uuid of the bit, as a string
		 */
		public string uuid { get; construct; }

		public Commit? primary_tip {
			/**
			 * wiz_bit_get_primary_tip:
			 * @self: A bit object
			 * @returns: The most recent version
			 */
			owned get {
				var pt = this.commits.get_primary_tip();
				if (pt != null)
					return new Commit(this, pt);
				return null;
			}
		}

		public List<Commit> tips {
			/**
			 * wiz_bit_get_tips:
			 * @self: A bit object
			 * @returns: All unmerged versions for the current bit
			 */
			owned get {
				var retval = new List<Commit>();
				foreach (var t in this.commits.get_tips())
					retval.append(new Commit(this, t));
				return retval;
			}
		}

		public Commit? root {
			/**
			 * wiz_bit_get_root:
			 * @self: A bit object
			 * @returns: The first version of this bit
			 *
			 * The root commit is the furthest point into the past for the bit, the
			 * only commit in a bit that has no parents.
			 *
			 * It is currently identified using a heuristic, fetching literally the
			 * oldest commit rather than following the DAG to its root. Because of this
			 * Wizbit doesn't support multi-rooted bits.
			 */
			owned get {
				var root = this.commits.get_root();
				if (root != null)
					return new Commit(this, root);
				return null;
			}
		}

		/**
		 * wiz_bit_new:
		 * @uuid: The uuid to create the bit for
		 * @store_path: The path to the store
		 * @returns: A bit object
		 */
		public Bit(string uuid, string? store_path) {
			this.uuid = uuid;
			this.store_path = store_path;

			/* This shouldn't be here */
			if (this.store_path == null) 
				this.store_path = Path.build_filename(Environment.get_home_dir(), ".wizbit");

			this.refs_path = Path.build_filename(this.store_path, "refs");
			this.objects_path = Path.build_filename(this.store_path, "objects");

			if (!FileUtils.test(this.store_path, FileTest.IS_DIR))
				DirUtils.create_with_parents(this.store_path, 0755);
			if (!FileUtils.test(this.refs_path, FileTest.IS_DIR))
				DirUtils.create_with_parents(this.refs_path, 0755);
			if (!FileUtils.test(this.objects_path, FileTest.IS_DIR))
				DirUtils.create_with_parents(this.objects_path, 0755);

			this.blobs = new BlobStore(this.objects_path);
			this.commits = new CommitStore(Path.build_filename(this.refs_path, uuid), uuid);
		}

		/**
		 * wiz_bit_has_version:
		 * @self: A bit object
		 * @uuid: The commit you want to test for
		 * @returns: True if bit has specified version, False otherwise.
		 */
		public bool has_version(string uuid) {
			return this.commits.has_commit(uuid);
		}

		/**
		 * wiz_bit_open_commit:
		 * @self: A bit object
		 * @uuid: The commit you want to open
		 * @returns: A commit object for the specified version uuid
		 */
		public Commit open_commit(string uuid) {
			return new Commit(this, uuid);
		}

		/**
		 * wiz_bit_get_iterator:
		 * @self: A bit object
		 * @version_uuid: The commit object you want to start iteration at
		 * @gatherer: A callback that allows you to control which nodes are visited on the next iterations
		 * @returns: A history iterator starting at the specified version_uuid
		 */
		private CommitIterator get_iterator(string version_uuid, CommitIterator.Gatherer gatherer) {
			var iter = new CommitIterator(gatherer);
			iter.append_queue(this.open_commit(version_uuid));
			return iter;
		}

		/**
		 * wiz_bit_get_commit_builder:
		 * @self: A bit object
		 * @returns: A new commit builder object
		 */
		public CommitBuilder get_commit_builder() {
			return new CommitBuilder(this);
		}

	}
}
