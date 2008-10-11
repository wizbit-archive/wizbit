using GLib;
using Wiz;

public class SyncSource : Object {
	public Wiz.Store store { private get; construct; }

	uint size;
	Wiz.BreadthFirstIterator iter;

	public SyncSource(Wiz.Store store) {
		this.store = store;
	}

	public List<string> tell_me_about(List<string> objects) {
		/*
		 * tell_me_about
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
		return retval;
	}

	public string grab_commit(string version_uuid) {
		return "crap we have no api to get this";
	}

	public string grab_blob(string version_uuid) {
		var v = this.store.open_version("nomnom", version_uuid);
		return v.read_as_string();
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

	public void pull(SyncSource server, Wiz.Bit bit) {
		var object_uuids = new List<string>();
		object_uuids.append(bit.uuid);

		/* Tell the server what objects we are interested in pulling */
		server.tell_me_about(object_uuids);

		var sounds_yummy = new Queue<string>();
		var do_not_want = new Queue<string>();
		var shas = server.search_for_shas(do_not_want);

		while (shas.length() > 0) {
			do_not_want = new Queue<string>();
			foreach (var sha in shas) {
				if (this.store.has_version(sha))
					do_not_want.push_tail(sha);
				else
					sounds_yummy.push_tail(sha);
			}
			shas = server.search_for_shas(do_not_want);
		}

		do {
			var uuid = sounds_yummy.pop_tail();
			var commit = server.grab_commit(uuid);
			var blob = server.grab_blob(uuid);

			debug(blob);
		} while (sounds_yummy.get_length() > 0);
	}
}

void test_simple_1()
{
	var a = new Wiz.Store("some_uuid", "data/sync_simple_1_a");

	var z = a.create_bit();

	assert( z.tips.length() == 0 );

	var a1 = z.create_next_version_from_string("1");
	var a2 = z.create_next_version_from_string("2", a1);
	var a3 = z.create_next_version_from_string("3", a2);
	var a4 = z.create_next_version_from_string("4", a3);
	var a5 = z.create_next_version_from_string("5", a4);

	assert( z.tips.length() == 1 );

	var a6 = z.create_next_version_from_string("6", a2);
	var a7 = z.create_next_version_from_string("7", a6);
	var a8 = z.create_next_version_from_string("8", a7);
	var a9 = z.create_next_version_from_string("9", a8);

	assert( z.tips.length() == 2 );

	var b = new Wiz.Store("some_uuid", "data/sync_simple_1_b");

	var sa = new SyncSource(a);
	var sb = new SyncClient(b);
	sb.pull(sa, z);
}

void test_sync()
{
	var a = new Wiz.Store("some_uuid", "data/sync_a");

	var z = a.create_bit();
	var a18 = z.create_next_version_from_string("18");
	var a17 = z.create_next_version_from_string("17");
	var a16 = z.create_next_version_from_string("16");
	var a15 = z.create_next_version_from_string("15");
	var a14 = z.create_next_version_from_string("14");
	var a13 = z.create_next_version_from_string("13", a18);
	var a12 = z.create_next_version_from_string("12", a17);
	var a11 = z.create_next_version_from_string("11", a16);
	var a10 = z.create_next_version_from_string("10", a14); // [a14, a15]);
	var a9 = z.create_next_version_from_string("9", a10); // [a10, a11]);
	var a8 = z.create_next_version_from_string("8", a13);
	var a7 = z.create_next_version_from_string("7", a12);
	var a6 = z.create_next_version_from_string("6", a9);
	var a5 = z.create_next_version_from_string("5", a9);
	var a4 = z.create_next_version_from_string("4", a8);
	var a3 = z.create_next_version_from_string("3", a7);
	var a2 = z.create_next_version_from_string("2", a6);
	var a1 = z.create_next_version_from_string("1", a5);
	// a.tips = [a1, a2, a3, a4]

	stdout.printf("MONKEY: %u", z.tips.length());
	assert(z.tips.length() == 4);

	/*
	var b = new Wiz.Store("some_uuid", "data/sync_b");
	b18 = y.create_next_version_from_string("18");
	b16 = y.create_next_version_from_string("16");
	b15 = y.create_next_version_from_string("15");
	b14 = y.create_next_version_from_string("14");
	b13 = y.create_next_version_from_string("13", [b18]);
	b11 = y.create_next_version_from_string("11", [b16]);
	b10 = y.create_next_version_from_string("10", [b14, b15]);
	b9 = y.create_next_version_from_string("9", [b10, b11]);
	b8 = y.create_next_version_from_string("8", [b13]);
	b6 = y.create_next_version_from_string("6", [b9]);
	b4 = y.create_next_version_from_string("4", [b8]);
	// b.tips = [b6, b4]
	*/

	var b = new Wiz.Store("some_uuid", "data/sync_b");

	var sa = new SyncSource(a);
	var sb = new SyncClient(b);
	sb.pull(sa, z);
}

public static void main (string[] args) {
	if (!FileUtils.test("data", FileTest.IS_DIR)) {
		DirUtils.create_with_parents("data", 0755);
		/* Should write some data to the file data/blob-data */
	}
	Test.init (ref args);
	Test.add_func("/wizbit/sync/1", test_simple_1);
	/* Test.add_func("/wizbit/sync/1", test_sync); */
	Test.run();
}
