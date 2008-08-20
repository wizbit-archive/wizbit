using GLib;
using Store;

namespace Wiz {
	public class Object : GLib.Object {

		private string store_path;
		private string objects_path;
		private string wc_path;
		private Store.Store store;

		private Version _primary_tip;
		public Version primary_tip {
			get {
				return _primary_tip;
			}
		}

		private List<Version> _tips;
		public List<Version> tips {
			get {
				return _tips;
			}
		}

		construct {
			this.store_path = "%s/.wizbit".printf(Environment.get_home_dir());
			this.objects_path = "%s/objects".printf(this.store_path);
			this.wc_path = "%s/wc".printf(this.store_path);

			this.store = new Store.Store(this.objects_path);
		}

		Object(string uuid) {
		}

		public OutputStream create_next_version() {
			return new OutputStream();
		}
	}
}
