using GLib;
using Graph;

namespace Wiz {
	public class Version : GLib.Object {
		/* A Version is a pair of Graph objects, one representing the commit
		 * the other representing the blob
		 */
		public Bit bit { get; construct; }
		public string version_uuid { get; construct; }

		private RarCommit commit;

		/* deprecated */
		protected string blob_id {
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

		public Version? #previous {
			get {
				var v = this.bit.commits.get_backward(this.version_uuid);
				if (v == null)
					return null;
				return new Version(this.bit, v);
			}
		}

		public Version? #next {
			get {
				var v = this.bit.commits.get_forward(this.version_uuid);
				if (v == null)
					return null;
				return new Version(this.bit, v);
			}
		}

		public List<Version> #parents {
			get {
				var parents = new List<Version>();
				foreach (var p in this.bit.commits.get_backwards(this.version_uuid))
					parents.append(new Version(this.bit, p));
				return parents;
			}
		}

		public List<Version> #children {
			get {
				var children = new List<Version>();
				foreach (var c in this.bit.commits.get_forwards(this.version_uuid))
					children.append(new Version(this.bit, c));
				return children;
			}
		}

		private Graph.Blob blob;
		private MappedFile file;

		public Version(Bit bit, string version_uuid) {
			this.bit = bit;
			this.version_uuid = version_uuid;
		}

		construct {
			this.commit = this.bit.commits.lookup_commit(this.version_uuid);
		}

		void _open_blob() throws GLib.FileError {
			if (this.file == null) {
				this.blob = new Graph.Blob.from_uuid(this.bit.blobs, this.commit.blob);
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
