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

		public bool read(string uuid, out char *bufptr, out long size) {
			string path = this.get_path_for_uuid(uuid);
			MappedFile obj = new MappedFile(path, false);
			bufptr = obj.get_contents();
			size = obj.get_length();
			return true;
		}

		public string write(Object obj) {
			return "somesha1";
		}
	}

	public class Object : GLib.Object {
		public bool parsed { get; set; }
		public Store store { get; construct; }
		public string uuid { get; construct; }

		public Object(Store store) {
			this.store = store;
			this.parsed = true;
		}

		public Object.from_uuid(Store store, string uuid) {
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
			char *bufptr;
			long size;
			this.store.read(this.uuid, out bufptr, out size);
			return new MemoryInputStream.from_data(bufptr, size, null);
		}

		/* Duplicated because vala won't use the ones in Object yet */
		public Blob(Store store) {
			this.store = store;
			this.parsed = true;
		}
		public Blob.from_uuid(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		public void set_contents_from_file(string path) {
		}

		public void serialize(OutputStream stream) {
		}
	}

	public class Tree : Object {
		public Blob blob { get; set; }

		/* Duplicated because vala won't use the ones in Object yet */
		public Tree(Store store) {
			this.store = store;
			this.parsed = true;
		}
		public Tree.from_uuid(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		public void unserialize() {
			char *bufptr;
			long size;

			if (!this.store.read(this.uuid, out bufptr, out size))
				return;
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

		/* Duplicated because vala won't use the ones in Object yet */
		public Commit(Store store) {
			this.store = store;
			this.parsed = true;
		}
		public Commit.from_uuid(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		public void unserialize() {
			char *bufptr;
			long size;
			long mark;
			long pos;

			if (!this.store.read(this.uuid, out bufptr, out size))
				return;

			if (!matches(bufptr, "tree"))
				return;

			mark = pos = 6;
			while (bufptr[pos] != '\n')
				pos ++;

			this.tree = new Git.Tree.from_uuid(this.store, ((string)bufptr).substring(mark, pos-mark));

			mark = pos = pos+1;
			while (bufptr[pos] != '\n')
				pos ++;

			this.author = ((string)bufptr).substring(mark, pos-mark);

			mark = pos = pos+1;
			while (bufptr[pos] != '\n')
				pos ++;

			this.committer = ((string)bufptr).substring(mark, pos-mark);
			
			mark = pos = pos+1;
			this.message = ((string)bufptr).substring(mark, size-mark);
		}

		public void serialize(OutputStream stream) {
			StringBuilder commit = new StringBuilder();
			commit.printf("tree %s\n", this.tree.uuid);
			commit.printf("author %s\n", this.author);
			commit.printf("committer %s\n", this.committer);
			commit.printf("%s\n", this.message);
			
			stdout.printf(commit.str);
		}

		private bool matches (char* begin, string keyword) {
			char* keyword_array = keyword;
			long len = keyword.len ();
			for (int i = 0; i < len; i++) {
				if (begin[i] != keyword_array[i]) {
					return false;
				}
			}
			return true;
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

		/* Duplicated because vala won't use the ones in Object yet */
		public Tag(Store store) {
			this.store = store;
			this.parsed = true;
		}
		public Tag.from_uuid(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		public void unserialize() {
			char *bufptr;
			long size;

			if (!this.store.read(this.uuid, out bufptr, out size))
				return;

		}

		public void serialize(OutputStream stream) {
		}
	}
}
