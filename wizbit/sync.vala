using GLib;
using Wiz;

public class SyncSource : Object {
	public Wiz.Store store { private get; construct; }

	uint size;
	Wiz.BreadthFirstIterator iter;

	public SyncSource(Wiz.Store store) {
		this.store = store;
	}

	public List<string> search_for_all_objects() {
		var objs = new List<string>();

		/* at the moment we don't have api to list objects so lets enum
		 * ths tips folder
		 */
		var path = Path.build_filename(this.store.directory, "refs");
		var dir = Dir.open(path);
		var f = dir.read_name();
		while (f != null) {
			objs.append(f);
			f = dir.read_name();
		}

		this.search_for_objects(objs);

		return objs;
	}

	public List<string> search_for_objects(List<string> objects) {
		/*
		 * search_for_objects
		 * @objects: A list of object ids that we want to pull
		 *
		 * Returns: A list of objects that arent on the source
		 *
		 * When pulling from a sync source, a client uses this method
		 * to set which objects to bfs over.
		 *
		 * FIXME: This is a bit FAIL because we can only pull objects
		 * we know about...
		 */
		this.size = 0;
		this.iter = new Wiz.BreadthFirstIterator();
		var retval = new List<string>();
		foreach (var o in objects) {
			if (this.store.has_bit(o)) {
				var bit = this.store.open_bit(o);
				foreach (var t in bit.tips) {
					this.iter.add_version(t);
					this.size++;
				}
			} else {
				retval.append(o);
			}
		}
		return retval;
	}

	public List<string> search_for_shas(Queue<string> versions) {
		/*
		 * search_for_shas
		 * @versions: A list of versions to kick out of the iterator
		 * 
		 * Returns: A list of versions found by the breadth first search
		 */
		for (uint i = 0; i < versions.get_length(); i++) {
			var v = versions.peek_nth(i);
			var wz = this.store.open_version("rarar", v);
			this.iter.kick_out(wz);
		}

		var retval = new List<string>();
		var found = this.iter.get(this.size);
		foreach (var f in found) {
			retval.append(f.version_uuid);
		}
		this.size *= 2;
		debug("%u", retval.length());
		return retval;
	}

	public string grab_commit(string version_uuid) {
		// var c = this.store.commits.lookup_commit(version_uuid);
		RarCommit c;

		var builder = new StringBuilder();
		builder.append("blob %s\n".printf(c.blob));
		foreach (var parent in c.parents)
			builder.append("parent %s\n".printf(parent));
		builder.append("committer %s\n".printf(c.committer));
		builder.append("timestamp %d\n".printf(c.timestamp));

		return builder.str;
	}

	public string grab_blob(string version_uuid) {
		var v = this.store.open_version("nomnom", version_uuid);
		return "%s%s".printf(v.blob_id, v.read_as_string());
	}
}

public class SyncClient : Object {
	Wiz.BreadthFirstIterator iter;

	public Wiz.Store store { private get; construct; }

	public SyncClient(Wiz.Store store) {
		this.store = store;
	}

	construct {
		this.iter = new Wiz.BreadthFirstIterator();
	}

	public void pull(SyncSource server) {
		/* Tell the server what objects we are interested in pulling */
		var objs = server.search_for_all_objects();

		var want = new Queue<string>();
		var do_not_want = new Queue<string>();
		var shas = server.search_for_shas(do_not_want);

		while (shas.length() > 0) {
			do_not_want = new Queue<string>();
			foreach (var sha in shas) {
				if (this.store.has_version(sha))
					do_not_want.push_tail(sha);
				else
					want.push_tail(sha);
			}
			shas = server.search_for_shas(do_not_want);
		}

		debug("there are %u blobs to pull", want.get_length());
		while (want.get_length() > 0) {
			var uuid = want.pop_tail();
			this.drop_commit(uuid, server.grab_commit(uuid));

			var blob = server.grab_blob(uuid);
			this.drop_raw(blob.substring(0,40), blob.substring(40, blob.len()));
		};
	}

	private bool matches (char* begin, string keyword) {
		char* keyword_array = keyword;
		long len = keyword.len ();
		for (int i = 0; i < len; i++)
			if (begin[i] != keyword_array[i])
				return false;
		return true;
	}

	void drop_commit(string uuid, string raw) {
		char *bufptr;
		long size;
		long mark;
		long pos;

		var c = new RarCommit();

		bufptr = (char *) raw;
		size = raw.len();

		if (!matches(bufptr, "blob "))
			return;

		mark = pos = 5;
		while (bufptr[pos] != '\n' && pos < size)
			pos ++;

		c.blob = ((string)bufptr).substring(mark, pos-mark);
		mark = pos = pos+1;

		while (matches(&bufptr[pos], "parent ")) {
			mark = pos = pos + 7;
			while (bufptr[pos] != '\n' && pos < size)
				pos ++;

			c.parents.append(((string)bufptr).substring(mark, pos-mark));
			mark = pos = pos+1;
		}

		if (!matches(&bufptr[pos], "committer "))
			return;

		mark = pos = pos+10;
		while (bufptr[pos] != '\n' && pos < size)
			pos ++;

		c.committer = ((string)bufptr).substring(mark, pos-mark);


		if (!matches(&bufptr[pos], "timestamp "))
			return;

		mark = pos = pos+10;
		while (bufptr[pos] != '\n' && pos < size)
			pos ++;
		string tmptimestamp = ((string)bufptr).substring(mark, pos-mark);
		c.timestamp = tmptimestamp.to_int();

		// bit.commits.store_commit(c);
	}

	void drop_raw(string uuid, string raw) {
		string drop_dir = Path.build_filename(this.store.directory, "objects", uuid.substring(0,2));
		if (!FileUtils.test(drop_dir, FileTest.IS_DIR))
			DirUtils.create_with_parents(drop_dir, 0755);
		string drop_path = Path.build_filename(drop_dir, uuid.substring(2,40));
		FileUtils.set_contents(drop_path, raw);
	}
}
