using GLib;

namespace Wiz.Private {

	/**
	 * Represents a collection of raw objects
	 */
	internal class BlobStore : GLib.Object {

		public string directory { get; construct; }

		/**
		 * Creates a new BlobStore object
		 *
		 * @param      directory to store blobs in
		 * @returns    a new BlobStore object
		 */
		public BlobStore(string directory) {
			if (!FileUtils.test(directory, FileTest.IS_DIR))
				DirUtils.create_with_parents(directory, 0755);
			this.directory = directory;
		}

		private string get_path_for_uuid(string uuid) {
			string folder = Path.build_filename(this.directory, uuid.substring(0,2));
			DirUtils.create_with_parents(folder, 0755);
			return Path.build_filename(folder, uuid.substring(2,38));
		}

		/**
		 * wiz_private_blob_store_exists:
		 *
		 * @param uuid    unique identfier
		 * @returns       true if object is store, false otherwise
		 *
		 * Does an object with a given unique identifier exist in this store
		 */
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


	/**
	 * Represents a single raw object
	 */
	internal class Blob : GLib.Object {
		public bool parsed { get; set; }
		public BlobStore store { get; construct; }
		public string uuid { get; set; }

		private MappedFile file;
		private void *bufptr;
		private long size;

		public MappedFile read() throws GLib.FileError {
			return this.store.read(this.uuid);
		}

		public Blob(BlobStore store) {
			this.store = store;
			this.parsed = true;
		}
		public Blob.from_uuid(BlobStore store, string uuid) {
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
