using GLib;

namespace Wiz {

	/* WizFile:
	 *
	 * The File object allows you to interact with streams in different ways.
	 *
	 * When accessing an existing commit, you can use the file object to access
	 * data as memory mapped data, as a GIO stream or as a string.
	 *
	 * When preparing a stream for a new commit, you can use GIO streams or the
	 * simple and dirty wiz_file_set_contents() method.
	 *
	 * It also provides a unix fd for people who called 1962 and asked for their
	 * insanity back.
	 */
	public class File : GLib.Object {
		private string parent_hash;
		private GLib.File temp_file;

		public File() {
			GLib.File store = GLib.File.new_for_path(Environment.get_tmp_dir());
			this.temp_file = GLib.File.new_for_path(store.get_path() + "/" + generate_uuid());
		}

		internal File.from_blob(Wiz.Private.Blob blob) {
			// FIXME: Make temp file creation lazier
			// E.g. Replace case doesnt need to bother with checking out a temp file
			this.parent_hash = blob.uuid;
			this.temp_file = blob.get_temp_file();
		}

		/**
		 * wiz_file_get_contents:
		 * @self: The file to get the contents of
		 * @error: A GError for when something goes wrong
		 * @returns: The contents of the file as a string.
		 */
		public string get_contents() throws FileError {
			string contents;
			long length;
			FileUtils.get_contents(this.get_path(), out contents, out length);
			return contents;
		}

		/**
		 * wiz_file_set_contents:
		 * @self: The file object to set the contents of
		 * @contents: A string to load into the file object
		 * @length: The length of data to load into the file
		 * @error: A GError for when something goes wrong.
		 *
		 * Set the contents of the file from a string.
		 */
		public void set_contents(string contents, long length = -1) throws FileError {
			FileUtils.set_contents(this.get_path(), contents, length);
		}

		/**
		 * wiz_file_get_mapped_file:
		 * @self: The file object from which to get a #GMappedFile
		 * @returns: A #GMappedFile object
		 */
		public MappedFile get_mapped_file() {
			return new MappedFile(this.get_path(), false);
		}

		/**
		 * wiz_file_read:
		 * @self: The file object from which to get a #GInputStream
		 * @returns: A #GInputStream for reading from the resource
		 */
		public GLib.InputStream read() {
			return this.temp_file.read(null);
		}

		/**
		 * wiz_file_append_to
		 * @self: The file object to get a #GOutputStream for
		 * @returns: A #GOutputStream for append to a resource
		 */
		public GLib.OutputStream append_to() {
			return this.temp_file.append_to(FileCreateFlags.PRIVATE, null);	
		}

		/**
		 * wiz_file_replace
		 * @self: The file object to get a #GOutputStream for
		 * @returns: A #GOutputStream for replacing a resource
		 */
		public GLib.OutputStream replace() {
			return this.temp_file.replace(null, false, FileCreateFlags.PRIVATE, null);
		}

		/**
		 * wiz_file_hash:
		 * @self: The file object to hash
		 * @returns: The hash of the file
		 *
		 * Hashing function, generates a hash of this file once the hash is 
		 * generated this file can no longer be changed, all other writes
		 * should land on a new commit.
		 */
		public string hash() {
			return "HASH GENERATED ON CLOSE?";
		}

		/**
		 * wiz_file_get_path:
		 * @self: The file object to inspect
		 * @returns: The temporary path where the file is currently checked out
		 */
		public string get_path() {
			return this.temp_file.get_path();
		}
	}
}
