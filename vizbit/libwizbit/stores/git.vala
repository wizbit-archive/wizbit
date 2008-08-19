using GLib;
using ZLib;

/* FIXME:
 *
 * In order to get things moving as quickly as possible i am just vommiting code. As such there are
 * at *least* the following inconsistencies:
 *
 * 1. Sha1 is passed around as a string. In the tree this should definitely be a binary sha1 
 * (for Git compatibility)
 *
 * 2. Trees don't support subtrees. We don't actually need trees within trees for wizbit so i said
 * stuff it.
 *
 * 3. Multiple parents. We /will/ need this but i don't like thinking about API on empty stomach. Or
 * without whisky.
 *
 */

namespace Git {

	public class Store : GLib.Object {
		/* The store just provides a way to read or write from the store.
		   It hides whether or not we are dealing with loose or packed objects
		*/

		private GLib.Vfs vfs;

		public string directory { get; construct; }

		public Store(string directory) {
			this.directory = directory;
		}

		construct {
			this.vfs = new GLib.Vfs();
		}

		private string get_path_for_uuid(string uuid) {
			return this.directory + "/" + uuid.substring(1,2) + "/" + uuid.substring(3,40);
		}

		public GLib.InputStream read(string uuid) {
			string path = this.get_path_for_uuid(uuid);
			File file = this.vfs.get_file_for_path(path);
			return file.read(null);
		}

		public string write(Object obj) {
			return "somesha1";
		}
	}

	public class Object : GLib.Object {
		public bool parsed { get; set; }
		public Store store { get; construct; }
		public string uuid { get; construct; }

		Object(Store store, string? uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		public string write() {
			return this.store.write(this);
		}

		public virtual void serialize(OutputStream stream) { }
	}

	public class Blob : Object {
		GLib.InputStream read() {
			return this.store.read(this.uuid);
		}

		public void set_contents_from_file(string path) {
		}

		public void serialize(OutputStream stream) {
		}
	}

	public class Tree : Object {
		public Blob blob { get; set; }

		public void unserialize() {
		}

		public void serialize(OutputStream stream) {
		}
	}

	public class Commit : Object {
		private Tree _tree;
		public Tree tree {
			get {
				if (!this._tree.parsed)
					this._tree.unserialize();
				return this._tree;
			}
			set {
				this._tree = value;
			}
		}
		public string author { get; set; }
		public string committer { get; set; }
		public string message { get; set; }

		public void unserialize() {
			GLib.InputStream stream = this.store.read(this.uuid);

			/* read stuff read stuff read stuff */
		}

		public void serialize(OutputStream stream) {
		}
	}

	public class Tag : Object {
		private Commit _commit;
		public Commit commit { 
			get {
				if (!this._commit.parsed)
					this._commit.unserialize();
				return this._commit;
			}
			set {
				this._commit = value;
			}
		}

		public void unserialize() {
			GLib.InputStream stream = this.store.read(this.uuid);

			/* read stuff read stuff read stuff */
		}

		public void serialize(OutputStream stream) {
		}
	}
}
