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
		/* The UUID becomes the name of the store
		 * stores like tomboy, calendars, contacts, email, files, etc...
		 */
			if (this.directory == null) {
				this.directory = Path.build_filename(Environment.get_home_dir(), ".wizbit/%s".printf(this.uuid));
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

		public Version open_version(string uuid, string version_uuid) {
			return new Version(this.store, version_uuid);
		}
	}
}