using GLib;
using Graph;

namespace Wiz {
	public class Bit : GLib.Object {
		/* A bit is a collection of tips, a tip being a Version object
		 * which represents the tip of a series of commits, this is almost 
		 * identical to a reference in git.
		 */
		private string refs_path;
		private string objects_path;
		private string wc_path;
		private Graph.Store store;

		public string store_path { get; construct; }
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
			/* This shouldn't be here */
			if (this.store_path == null) 
				this.store_path = Path.build_filename(Environment.get_home_dir(), ".wizbit");

			this.refs_path = Path.build_filename(this.store_path, "refs");
			this.objects_path = Path.build_filename(this.store_path, "objects");
			this.wc_path = Path.build_filename(this.store_path, "wc");

			if (!FileUtils.test(this.store_path, FileTest.IS_DIR))
				DirUtils.create_with_parents(this.store_path, 0755);
			if (!FileUtils.test(this.refs_path, FileTest.IS_DIR))
				DirUtils.create_with_parents(this.refs_path, 0755);
			if (!FileUtils.test(this.objects_path, FileTest.IS_DIR))
				DirUtils.create_with_parents(this.objects_path, 0755);
			if (!FileUtils.test(this.wc_path, FileTest.IS_DIR))
				DirUtils.create_with_parents(this.wc_path, 0755);

			this.store = new Graph.Store(this.objects_path);

			assert( this.uuid.len() > 0 );

			this.read_tips();
		}

		public Bit(string uuid, string? store_path) {
			this.uuid = uuid;
			this.store_path = store_path;
		}

		private void write_tips() {
			/* This should be replaced with Sqlite or some uber on disk format we have yet to imagine.
			 * Sod that for a pack of bourbonds, I want it to work already
			 */

			var builder = new StringBuilder();

			builder.append(this._primary_tip.version_uuid);
			builder.append("\n");

			foreach (var v in this._tips) {
				if (v.version_uuid != this._primary_tip.version_uuid) {
					builder.append(v.version_uuid);
					builder.append("\n");
				}
			}

			FileUtils.set_contents(Path.build_filename(this.refs_path, this.uuid), builder.str, builder.str.len());
		}

		private void read_tips() {
			/* This should be replaced with Sqlite or some uber on disk format we have yet to imagine.
			 *  Sod that for a game of soldiers, I want a demo already
			 */

			string contents;
			long size, mark, pos;
			Version v;

			string refs_path = Path.build_filename(this.refs_path, this.uuid);

			if (!FileUtils.test(refs_path, FileTest.EXISTS))
				return;

			FileUtils.get_contents(refs_path, out contents, out size);

			mark = pos = 0;
			while (contents[pos] != '\n' && pos < size)
				pos ++;
			this._primary_tip = new Version(this.store, contents.substring(mark, pos-mark));
			this._tips.append(this._primary_tip);

			while (pos < size) {
				mark = pos = pos+1;

				while (contents[pos] != '\n' && pos < size)
					pos ++;
				if ((pos-mark) > 0)
					this._tips.append(new Version(this.store, contents.substring(mark, pos-mark)));
			}
				
		}

		public OutputStream create_next_version() {
			return new OutputStream();
		}

		public Version create_next_version_from_string(string data, Version ?parent = null) {
			var blob = new Graph.Blob(this.store);
			blob.set_contents((void *)data, data.len());
			blob.write();

			var commit = new Graph.Commit(this.store);
			commit.blob = blob;
			if (parent != null)
				commit.parents.append( parent.commit );
			commit.author = "John Carr <john.carr@unrouted.co.uk>";
			commit.committer = "John Carr <john.carr@unrouted.co.uk>";
			commit.message = "I don't like Mondays";
			commit.write();

			var new_version = new Version(this.store, commit.uuid);

			foreach (var v in this._tips) {
				if (v.version_uuid == this._primary_tip.version_uuid) {
					this._tips.remove(v);
					break;
				}
			}
			this._tips.append(new_version);
			this._primary_tip = new_version;
			this.write_tips();

			return new_version;
		}
	}
}
