using GLib;

namespace Wiz {
	public class OutputStream : GLib.OutputStream {
		UnixOutputStream _stream;
		string _path;

		construct {
			int fd = FileUtils.open_tmp ("wizbit_XXXXXX", out this._path);
			this._stream = new UnixOutputStream(fd, true);
		}

		void commit () {
			/* Generate a new commit
			 *
			 * At the moment, this operates on our temporary file (_path)
			 * Create a blob from it, commit it and then delete the temp
			 * file
			 */

			stdout.printf("committing\n");
		}

		public void clear_pending () {
			this._stream.clear_pending();
		}
		public bool close (GLib.Cancellable? cancellable) throws GLib.Error {
			this.commit();
			return this._stream.close(cancellable);
		}
		public bool has_pending () {
			return this._stream.has_pending();
		}
		public bool is_closed () {
			return this._stream.is_closed();
		}
		public bool set_pending () throws GLib.Error {
			return this._stream.set_pending();
		}
		public long write (void* buffer, ulong count, GLib.Cancellable? cancellable) throws GLib.Error {
			return this._stream.write(buffer, count, cancellable);
		}
		public bool write_all (void* buffer, ulong count, out ulong bytes_written, GLib.Cancellable? cancellable) throws GLib.Error {
			return this._stream.write_all(buffer, count, out bytes_written, cancellable);
		}
		public virtual void close_async (int io_priority, GLib.Cancellable? cancellable, GLib.AsyncReadyCallback callback) {
			this._stream.close_async(io_priority, cancellable, callback);
		}
		public virtual bool close_finish (GLib.AsyncResult _result) throws GLib.Error {
			return this._stream.close_finish(_result);
		}
		public virtual bool flush (GLib.Cancellable? cancellable) throws GLib.Error {
			return this._stream.flush(cancellable);
		}
		public virtual void flush_async (int io_priority, GLib.Cancellable? cancellable, GLib.AsyncReadyCallback callback) {
			this._stream.flush_async(io_priority, cancellable, callback);
		}
		public virtual bool flush_finish (GLib.AsyncResult _result) throws GLib.Error {
			return this._stream.flush_finish(_result);
		}
		public virtual long splice (GLib.InputStream source, GLib.OutputStreamSpliceFlags flags, GLib.Cancellable? cancellable) throws GLib.Error {
			return this._stream.splice(source, flags, cancellable);
		}
		public virtual void splice_async (GLib.InputStream source, GLib.OutputStreamSpliceFlags flags, int io_priority, GLib.Cancellable?            cancellable, GLib.AsyncReadyCallback callback) {
			this._stream.splice_async(source, flags, io_priority, cancellable, callback);
		}
		public virtual long splice_finish (GLib.AsyncResult _result) throws GLib.Error {
			return this._stream.splice_finish(_result);
		}
		public virtual void write_async (void* buffer, ulong count, int io_priority, GLib.Cancellable? cancellable, GLib.AsyncReadyCallback          callback) {
			this._stream.write_async(buffer, count, io_priority, cancellable, callback);
		}
		public virtual long write_finish (GLib.AsyncResult _result) throws GLib.Error {
			return this._stream.write_finish(_result);
		}
	}
}
