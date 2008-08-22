using GLib;
using Store;

namespace Wiz {
	public class Version : GLib.Object {
		public Store.Store store { get; construct; }
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
				return new Version(this.store, this.commit.uuid);
			}
		}

		protected Store.Commit commit;
		private Store.Blob blob;

		private MappedFile file;

		public Version(Store.Store store, string version_uuid) {
			this.store = store;
			this.version_uuid = version_uuid;
		}

		construct {
			this.commit = new Store.Commit.from_uuid(store, this.version_uuid);
			this.commit.unserialize();
		}

		public GLib.InputStream read() {
			this.file = this.commit.blob.read();
			return new MemoryInputStream.from_data(file.get_contents(), file.get_length(), null);
		}
	}
}
