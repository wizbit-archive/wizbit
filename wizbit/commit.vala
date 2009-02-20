
namespace Wiz {
	internal class Commit {
		public string uuid { get; set; }
		public string blob { get; set; }
		public string committer { get; set; }
		public int timestamp { get; set; }
		public int timestamp2 {get; set; }
		public List<string> parents;

		public void Commit() {
			this.parents = new List<string>();
		}
	}
}
