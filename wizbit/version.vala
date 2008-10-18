using GLib;
using Graph;

namespace Wiz {
	public class Version : GLib.Object {
		/* A Version is a pair of Graph objects, one representing the commit
		 * the other representing the blob
		 */
		public Graph.Store store { get; construct; }
		public string version_uuid { get; construct; }

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

		/* to iterate every node in the dag we need all parents
		 * of all nodes
		 */
		public List<Version> #parents {
			get {
				var parents = new List<Version>();
				foreach (Commit parent in this.commit.parents) {
					if (!parent.parsed)
						parent.unserialize();
					parents.append(new Version(this.store, parent.uuid));
				}
				return parents;
			}
		}

		private Graph.Commit commit;
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
