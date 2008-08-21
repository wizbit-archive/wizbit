using GLib;
using Store;

namespace Wiz {
	public class Object : GLib.Object {

		private string store_path;
		private string refs_path;
		private string objects_path;
		private string wc_path;
		private Store.Store store;

		public string uuid { get; construct; }

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
			this.refs_path = "%s/refs".printf(this.store_path);
			this.objects_path = "%s/objects".printf(this.store_path);
			this.wc_path = "%s/wc".printf(this.store_path);

			this.store = new Store.Store(this.objects_path);

			assert( this.uuid.len() > 0 );

			this.unserialize();
		}

		Object(string uuid) {
			this.uuid = uuid;
		}

		private void unserialize() {
			/* This should be replaced with Sqlite or some uber on disk format we have yet to imagine.
			 *  Sod that for a game of soldiers, I want a demo already
			 */

			string contents;
			long size, mark, pos;
			Version v;
			FileUtils.get_contents(this.refs_path + "/" + this.uuid, out contents, out size);

			mark = pos = 0;
			while (contents[pos] != '\n')
				pos ++;
			this._primary_tip = new Version(this.store, contents.substring(mark, pos-mark));
			this._tips.append(this._primary_tip);

			while (pos < size) {
				mark = pos = pos+1;

				while (contents[pos] != '\n')
					pos ++;

				this._tips.append(new Version(this.store, contents.substring(mark, pos-mark)));
			}
				
		}

		public OutputStream create_next_version() {
			return new OutputStream();
		}
	}
}
