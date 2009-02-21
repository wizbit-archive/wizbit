using GLib;

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

		public Version? primary_tip {
			owned get {
				var pt = this.commits.get_primary_tip();
				if (pt != null)
					return new Version(this, pt);
				return null;
			}
		}

		public List<Version> tips {
			owned get {
				var retval = new List<Version>();
				foreach (var t in this.commits.get_tips())
					retval.append(new Version(this, t));
				return retval;
			}
		}

		public Version? root {
			owned get {
				var root = this.commits.get_root();
				if (root != null)
					return new Version(this, root);
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

		public bool has_version(string uuid) {
			return this.commits.has_commit(uuid);
		}

		public Version open_version(string uuid) {
			return new Version(this, uuid);
		}

		public CommitBuilder get_commit_builder() {
			return new CommitBuilder(this);
		}

	}
}
