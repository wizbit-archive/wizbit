using GLib;

namespace Wiz {
	public class Store : GLib.Object {
		public string uuid { get; construct; }
		public string directory { get; construct; }

		private Graph.Store store;

		string object_dir;
		string refs_dir;

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
			this.object_dir = Path.build_filename(this.directory, "objects");
			this.refs_dir = Path.build_filename(this.directory, "refs");

			if (!FileUtils.test(this.refs_dir, FileTest.IS_DIR))
				DirUtils.create_with_parents(this.refs_dir, 0755);
			if (!FileUtils.test(this.object_dir, FileTest.IS_DIR))
				DirUtils.create_with_parents(this.object_dir, 0755);

			this.store = new Graph.Store(this.object_dir);
		}

		public bool has_version(string uuid) {
			return this.store.exists(uuid);
		}

		public bool has_bit(string uuid) {
			return FileUtils.test(Path.build_filename(this.refs_dir, uuid), FileTest.EXISTS);
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
