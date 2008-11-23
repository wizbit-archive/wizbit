using GLib;

namespace Wiz {
	public class Bit : GLib.Object {
		/* A bit is a collection of tips, a tip being a Version object
		 * which represents the tip of a series of commits, this is almost 
		 * identical to a reference in git.
		 */
		private string refs_path;
		private string objects_path;

		protected Graph.Store blobs;
		public CommitStore commits;

		public string store_path { get; construct; }
		public string uuid { get; construct; }

		public Version? #primary_tip {
			get {
				var pt = this.commits.get_primary_tip();
				if (pt != null)
					return new Version(this, pt);
				return null;
			}
		}

		public List<Version> #tips {
			get {
				var retval = new List<Version>();
				foreach (var t in this.commits.get_tips())
					retval.append(new Version(this, t));
				return retval;
			}
		}

		public Version? #root {
			get {
				var root = this.commits.get_root();
				if (root != null)
					return new Version(this, root);
				return null;
			}
		}

		construct {
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

			this.blobs = new Graph.Store(this.objects_path);
			this.commits = new CommitStore(Path.build_filename(this.refs_path, uuid), uuid);
		}

		public Bit(string uuid, string? store_path) {
			this.uuid = uuid;
			this.store_path = store_path;
		}

		public bool has_version(string uuid) {
			return this.commits.has_commit(uuid);
		}

		public Version open_version(string uuid) {
			return new Version(this, uuid);
		}

		public OutputStream create_next_version() {
			return new OutputStream();
		}

		public Version create_next_version_from_string(string data, Version ?parent = null) {
			var blob = new Graph.Blob(this.blobs);
			blob.set_contents((void *)data, data.len());
			blob.write();

			var commit = new RarCommit();
			commit.blob = blob.uuid;
			if (parent != null)
				commit.parents.append( parent.version_uuid );
			// TODO Should get the committer from the env, or contacts :D
			commit.committer = "John Carr <john.carr@unrouted.co.uk>";
			commit.timestamp = (int) time_t();

			// my brain can imagine edge cases where this is wrong, but its only a heuristic
			// and is probably good enough
			var t = new TimeVal();
			t.get_current_time();
			commit.timestamp2 = (int) t.tv_usec;

			this.commits.store_commit(commit);

			var new_version = new Version(this, commit.uuid);
			return new_version;
		}

		public Version test_create_next_version_from_string(string data, Version ?parent = null, int timestamp) {
			var blob = new Graph.Blob(this.blobs);
			blob.set_contents((void *)data, data.len());
			blob.write();

			var commit = new RarCommit();
			commit.blob = blob.uuid;
			if (parent != null)
				commit.parents.append( parent.version_uuid );
			// TODO Should get the committer from the env, or contacts :D
			commit.committer = "John Carr <john.carr@unrouted.co.uk>";
			commit.timestamp = timestamp;

			// my brain can imagine edge cases where this is wrong, but its only a heuristic
			// and is probably good enough
			//var t = new TimeVal();
			//t.get_current_time();
			commit.timestamp2 = 0;//(int) t.tv_usec;

			this.commits.store_commit(commit);

			var new_version = new Version(this, commit.uuid);
			return new_version;
		}
	}
}
