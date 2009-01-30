using GLib;

/* FIXME:
 *
 * In order to get things moving as quickly as possible i am just vommiting code. As such there are
 * at *least* the following inconsistencies:
 *
 * 1. This list of fixmes is out of date.
 *
 */

namespace Graph {

	public class Store : GLib.Object {
		/* The store just provides a way to read or write from the store.
		   It hides whether or not we are dealing with loose or packed objects
		*/

		public string directory { get; construct; }

		public Store(string directory) {
			this.directory = directory;
		}

		private string get_path_for_uuid(string uuid) {
			string folder = Path.build_filename(this.directory, uuid.substring(0,2));
			DirUtils.create_with_parents(folder, 0755);
			return Path.build_filename(folder, uuid.substring(2,38));
		}

		public bool exists(string uuid) {
			return FileUtils.test(this.get_path_for_uuid(uuid), FileTest.EXISTS);
		}

		public MappedFile read(string uuid) throws GLib.FileError {
			string path = this.get_path_for_uuid(uuid);
			return new MappedFile(path, false);
		}

		public string write(Blob obj) throws GLib.FileError{
			void *bufptr;
			long size;
			obj.serialize(out bufptr, out size);
			Checksum sha1 = new Checksum(ChecksumType.SHA1);
			sha1.update((uchar [])bufptr, size);
			string uuid = sha1.get_string();
			FileUtils.set_contents(this.get_path_for_uuid(uuid), (string)bufptr, size);
			return uuid;
		}
	}

	public class Blob : GLib.Object {
		public bool parsed { get; set; }
		public Store store { get; construct; }
		public string uuid { get; set; }

		private MappedFile file;
		private void *bufptr;
		private long size;

		public MappedFile read() throws GLib.FileError {
			return this.store.read(this.uuid);
		}

		public Blob(Store store) {
			this.store = store;
			this.parsed = true;
		}
		public Blob.from_uuid(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		public void set_contents(void *bufptr, long size) {
			this.bufptr = bufptr;
			this.size = size;
		}

		public void set_contents_from_file(string path) throws GLib.FileError {
			this.file = new MappedFile(path, false);
			this.bufptr = file.get_contents();
			this.size = file.get_length();
		}

		public void serialize(out void *bufptr, out long size) {
			bufptr = this.bufptr;
			size = this.size;
		}

		public void write() throws GLib.FileError {
			this.uuid = this.store.write(this);
		}
	}
}
