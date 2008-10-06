using GLib;

namespace Wiz {
	public class Store : GLib.Object {
		public string uuid { get; construct; }
		public string directory { get; construct; }

		private Graph.Store store;

		public Store(string uuid, string? directory = null) {
			this.uuid = uuid;
			this.directory = directory;
		}
		
		construct {
			if (this.directory == null) {
				this.directory = Path.build_filename(Environment.get_home_dir(), ".wizbit");
			}
			this.store = new Graph.Store(this.directory);
		}

		public bool bit_exists(string uuid) {
			return this.store.exists(uuid);
		}

		public Bit create_bit() {
			return new Bit(generate_uuid(), this.directory);
		}

		public Bit open_bit(string uuid) {
			return new Bit(uuid, this.directory);
		}
	}
}
