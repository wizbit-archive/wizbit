using GLib;
using Wiz.Private;

namespace Wiz {
	public class Commit : GLib.Object {
		/* A Version is a pair of Graph objects, one representing the commit
		 * the other representing the blob
		 */

		public Bit bit { get; construct; }
		public string version_uuid { get; construct; }

		private Wiz.Private.Commit commit;

		public Commit(Bit bit, string version_uuid) {
			this.bit = bit;
			this.version_uuid = version_uuid;

			this.commit = this.bit.commits.lookup_commit(this.version_uuid);
		}

		/**
		 * wiz_version_get_blob_id:
		 * @returns: The sha of the blob associated with this version.
		 *
		 * Deprecated: 0.1
		 */
		internal string blob_id {
			get {
				return this.commit.blob;
			}
		}

		public string committer {
			get {
				return this.commit.committer;
			}
		}

		public int timestamp {
			get {
				return this.commit.timestamp;
			}
		}

		public Commit? previous {
			owned get {
				var v = this.bit.commits.get_backward(this.version_uuid);
				if (v == null)
					return null;
				return new Commit(this.bit, v);
			}
		}

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

		private Wiz.Private.Blob blob;
		private MappedFile file;

		public CommitBuilder get_commit_builder() {
			var cb = this.bit.get_commit_builder();
			cb.add_parent(this);
			return cb;
		}

		/* STUFF BELOW HERE CONSIDERED FAIL */

		void _open_blob() throws GLib.FileError {
			if (this.file == null) {
				this.blob = new Blob.from_uuid(this.bit.blobs, this.commit.blob);
				this.file = this.blob.read();
			}
		}

		public long get_length() throws GLib.FileError {
			this._open_blob();
			return this.file.get_length();
		}

		public GLib.InputStream read() throws GLib.FileError {
			this._open_blob();
			return new MemoryInputStream.from_data(this.file.get_contents(), this.file.get_length(), null);
		}

		public char *read_as_string() throws GLib.FileError {
			this._open_blob();
			return (char *)this.file.get_contents();
		}
	}
}
