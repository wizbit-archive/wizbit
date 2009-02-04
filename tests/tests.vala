
[Compact]
public class BaseTestSuite {
	void setup(void *fixture) {}
	void teardown(void *fixture) {}

	void assert_true(bool condition) {
		assert(condition);
	}
}

public class TestSuiteWithTempDir : BaseTestSuite {

	protected string directory;

	public void setup(void *fixture) {
		this.directory = DirUtils.mkdtemp(Path.build_filename(Environment.get_tmp_dir(), "XXXXXX"));
	}

	public void teardown(void *fixture) {
		DirUtils.remove(this.directory);
	}
}
