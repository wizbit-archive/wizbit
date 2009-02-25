using GLib;
using Wiz.Private;

namespace Wiz {
	public class Bit : GLib.Object {
		/* A bit is a collection of tips, a tip being a Version object
		 * which represents the tip of a series of commits, this is almost 
		 * identical to a reference in git.
		 */
		private string refs_path;
		private string objects_path;

		internal BlobStore blobs;
		public CommitStore commits;

		public string store_path { get; construct; }
		public string uuid { get; construct; }

		public Commit? primary_tip {
			/**
			 * wiz_bit_get_primary_tip:
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
			 * @returns: The first version of this bit
			 */
			owned get {
				var root = this.commits.get_root();
				if (root != null)
					return new Commit(this, root);
				return null;
			}
		}

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
		 * @returns: True if bit has specified version, False otherwise.
		 */
		public bool has_version(string uuid) {
			return this.commits.has_commit(uuid);
		}

		/**
		 * wiz_bit_open_commit:
		 * @returns: A commit object for the specified version uuid
		 */
		public Commit open_commit(string uuid) {
			return new Commit(this, uuid);
		}

		/**
		 * wiz_bit_get_iterator:
		 * @returns: A history iterator starting at the specified version_uuid
		 */
		public CommitIterator get_iterator(string version_uuid, CommitIterator.Gatherer gatherer) {
			var iter = new CommitIterator(gatherer);
			iter.append_queue(this.open_commit(version_uuid));
			return iter;
		}

		/**
		 * wiz_bit_get_commit_builder:
		 * @returns: A new commit builder object
		 */
		public CommitBuilder get_commit_builder() {
			return new CommitBuilder(this);
		}

	}
}
