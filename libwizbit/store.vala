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
				this.directory = "~/.wizbit/";
			}
		}

		public Object create_object() {
			return new Object("some_uuid_i_need_to_generate");
		}
	}
}
