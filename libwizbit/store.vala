using GLib;

namespace Wiz {
	public class Store : GLib.Object {
		public string uuid { get; construct; }
		public string directory { get; construct; }

		public Store(string uuid, string directory) {
			this.uuid = uuid;
			this.directory = directory;
		}
		
		construct {
			if (this.directory == null) {
				this.directory = Path.build_filename(Environment.get_home_dir(), ".wizbit");
			}
		}

		public Bit create_bit() {
			return new Bit("some_uuid_i_need_to_generate");
		}

		public Bit open_bit(string uuid) {
			return new Bit(uuid);
		}
	}
}
