using GLib;
using Wiz;

public class SyncServer : Object {
	public Wiz.Store store { private get; construct; }

	public SyncServer(Wiz.Store store) {
		this.store = store;
	}

	public List<string> check(List<string> versions) {
		/*
		 * check
		 * @versions: A list of versions to check for
		 * 
		 * Returns: A list of versions we have
		 */
		var retval = new List<string>();
		foreach (var v in versions) {
			if (this.store.bit_exists(v))
				retval.append(v);
		}
		return retval;
	}

	public void here(string blob) {
		debug("i can has red veg nao?");
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

	public void push(SyncServer server, Wiz.Bit bit) {
		var need_to_send = new List<Version>();

		foreach (var v in bit.tips)
			this.iter.add_version(v);

		uint size = 4;
		while (!this.iter.end) {
			debug("i might send: %u\n", size);

			List<Version> to_send = this.iter.get(size);
			debug("sending: %u\n", to_send.length());

			List<Version> got_back = server.do_you_have(to_send);
			debug("got back: %u\n", got_back.length());

			foreach (var x in to_send) {
				bool flag = true;
				foreach (var y in got_back)
					if (x.version_uuid == y.version_uuid)
						flag = false;
				if (flag) {
					need_to_send.append(x);
					flag = false;
				}
			}
			debug("k, i need to send u: %u\n", need_to_send.length());

			foreach (var v in got_back)
				foreach (var p in v.parents)
					this.iter.kick_out(p);

			size *= 2;
		}

		foreach (var v in need_to_send)
			debug("ucanhas: %s\n", v.version_uuid);
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

	var sa = new SyncServer(a);
	var sb = new SyncClient(b);
	sb.sync(sa, z);
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

	var sa = new SyncServer(a);
	var sb = new SyncClient(b);
	sb.sync(sa, z.tips);
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
