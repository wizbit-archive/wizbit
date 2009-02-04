/* These bindings are now in Vala SVN. Here is a local copy until a new stable vala is released.
 */

[CCode (cprefix = "G", lower_case_cprefix = "g_", cheader_filename = "glib.h")]
namespace GLib {
	[Compact]
	[CCode (cname = "GTestCase", ref_function = "", unref_function = "")]
	public class TestCase {
		[CCode (cname = "g_test_create_case")]
	public TestCase (string test_name, size_t data_size, [CCode (delegate_target_pos = 2.9)] TestFunc data_setupvoid, [CCode (delegate_target_pos = 2.9)] TestFunc data_funcvoid, [CCode (delegate_target_pos = 2.9)] TestFunc data_teardownvoid);
	}

	[Compact]
	[CCode (cname = "GTestSuite", ref_function = "", unref_function = "")]
	public class TestSuite {
		[CCode (cname = "g_test_create_suite")]
		public TestSuite (string name);
		[CCode (cname = "g_test_get_root")]
		public static TestSuite get_root ();
		[CCode (cname = "g_test_suite_add")]
		public void add (TestCase test_case);
		[CCode (cname = "g_test_suite_add_suite")]
		public void add_suite (TestSuite test_suite);
	}

	public delegate void TestFunc (void* fixture);
}
