
public class TestSuiteWithTempDir {

	private string olddir;
	protected string directory;

	public void setup(void *fixture) {
		this.olddir = Environment.get_current_dir();
		this.directory = DirUtils.mkdtemp(Path.build_filename(Environment.get_tmp_dir(), "XXXXXX"));
		Environment.set_current_dir(this.directory);
	}

	public void teardown(void *fixture) {
		Environment.set_current_dir(this.olddir);
		DirUtils.remove(this.directory);
	}
}
