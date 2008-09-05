using GLib;
using Graph;

namespace Wiz {
	public class Version : GLib.Object {
		/* A Version is a pair of Graph objects, one representing the commit
		 * the other representing the blob
		 */
		public Graph.Store store { get; construct; }
		public string version_uuid { get; construct; }

		public string author {
			get {
				return this.commit.author;
			}
		}

		public string message {
			get {
				return this.commit.message;
			}
		}

		public Version #previous {
			get {
				if (this.commit.parents.length() == 0)
					return (Version)null;

				var c = this.commit.parents.nth_data(0);
				if (!c.parsed)
					c.unserialize();
				return new Version(this.store, c.uuid);
			}
		}

		protected Graph.Commit commit;
		private Graph.Blob blob;

		private MappedFile file;

		public Version(Graph.Store store, string version_uuid) {
			this.store = store;
			this.version_uuid = version_uuid;
		}

		construct {
			this.commit = new Graph.Commit.from_uuid(store, this.version_uuid);
			this.commit.unserialize();
		}

		public GLib.InputStream read() {
			this.file = this.commit.blob.read();
			return new MemoryInputStream.from_data(file.get_contents(), file.get_length(), null);
		}

		public string read_as_string() {
			this.file = this.commit.blob.read();
			return ((string)file.get_contents()).substring(0, file.get_length());
		}
	}
}
