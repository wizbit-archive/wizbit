using GLib;
using Wiz.Private;

namespace Wiz {
	public class Store : GLib.Object {
		public string uuid { get; construct; }
		public string directory { get; construct; }

		private BlobStore store;

		string refs_dir;

		public Store(string uuid, string? directory = null) {
			this.uuid = uuid;
			this.directory = directory;

			/* The UUID becomes the name of the store
			 * stores like tomboy, calendars, contacts, email, files, etc...
			 */
			if (this.directory == null) {
				this.directory = Path.build_filename(Environment.get_home_dir(), ".wizbit/%s".printf(this.uuid));
			}

			this.refs_dir = Path.build_filename(this.directory, "refs");
			if (!FileUtils.test(this.refs_dir, FileTest.IS_DIR))
				DirUtils.create_with_parents(this.refs_dir, 0755);

			this.store = new BlobStore(Path.build_filename(this.directory, "objects"));
		}

		public bool has_bit(string uuid) {
			return FileUtils.test(Path.build_filename(this.refs_dir, uuid), FileTest.EXISTS);
		}

		public List<string> list_bits() {
			var objs = new List<string>();
			var path = Path.build_filename(this.directory, "refs");
			var dir = Dir.open(path);
			var f = dir.read_name();
			while (f != null) {
				objs.append(f);
				f = dir.read_name();
			}
			return objs;
		}

		public Bit create_bit() {
			string uuid = generate_uuid();
			return new Bit(uuid, this.directory);
		}

		public Bit open_bit(string uuid) {
			return new Bit(uuid, this.directory);
		}
	}
}
