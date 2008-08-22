using GLib;
using Graph;

namespace Wiz {
	public class Object : GLib.Object {

		private string store_path;
		private string refs_path;
		private string objects_path;
		private string wc_path;
		private Graph.Store store;

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

			this.store = new Graph.Store(this.objects_path);

			assert( this.uuid.len() > 0 );

			this.read_tips();
		}

		public Object(string uuid) {
			this.uuid = uuid;
		}

		private void write_tips() {
			/* This should be replaced with Sqlite or some uber on disk format we have yet to imagine.
			 * Sod that for a pack of bourbonds, I want it to work already
			 */

			StringBuilder builder = new StringBuilder();

			builder.append(this._primary_tip.version_uuid);
			builder.append("\n");

			foreach (Version v in this._tips) {
				if (v != this._primary_tip) {
					builder.append(v.version_uuid);
					builder.append("\n");
				}
			}

			FileUtils.set_contents(this.refs_path + "/" + this.uuid, builder.str, builder.str.len());
		}

		private void read_tips() {
			/* This should be replaced with Sqlite or some uber on disk format we have yet to imagine.
			 *  Sod that for a game of soldiers, I want a demo already
			 */

			string contents;
			long size, mark, pos;
			Version v;
			FileUtils.get_contents(this.refs_path + "/" + this.uuid, out contents, out size);

			mark = pos = 0;
			while (contents[pos] != '\n' && pos < size)
				pos ++;
			this._primary_tip = new Version(this.store, contents.substring(mark, pos-mark));
			this._tips.append(this._primary_tip);

			while (pos < size) {
				mark = pos = pos+1;

				while (contents[pos] != '\n' && pos < size)
					pos ++;

				this._tips.append(new Version(this.store, contents.substring(mark, pos-mark)));
			}
				
		}

		public OutputStream create_next_version() {
			return new OutputStream();
		}

		public Version create_next_version_from_string(string data, Version ?parent) {
			Graph.Blob blob = new Graph.Blob(this.store);
			blob.set_contents((void *)data, data.len());
			blob.write();

			Graph.Commit commit = new Graph.Commit(this.store);
			commit.blob = blob;
			if (parent != null)
				commit.parents.append( parent.commit );
			commit.author = "John Carr <john.carr@unrouted.co.uk>";
			commit.committer = "John Carr <john.carr@unrouted.co.uk>";
			commit.message = "I don't like Mondays";
			commit.write();

			Version new_version = new Version(this.store, commit.uuid);

			this._primary_tip = new_version;
			this.write_tips();

			return new_version;
		}
	}
}
