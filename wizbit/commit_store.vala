using GLib;
using Sqlite;

namespace Wiz {
	internal class CommitStore {
		public string directory { get; construct; }

		private static const string CREATE_COMMITS_TABLE =
			"CREATE TABLE commits(uuid VARCHAR(40), blob VARCHAR(40))";

		private static const string CREATE_RELATIONS_TABLE =
			"CREATE TABLE relations(node_id VARCHAR(40), parent_id VARCHAR(40))";

		private Database db;

		private Statement create_commits_table;
		private Statement create_relations_table;

		public CommitStore(string directory) {
			this.directory = directory;
		}

		construct {
			/* test and create commits directory */

			Database.open(":memory:", out this.db);

			this.db.prepare(CREATE_COMMITS_TABLE, -1,
				out this.create_commits_table);
			this.db.prepare(CREATE_RELATIONS_TABLE, -1,
				out this.create_relations_table);

			int val = this.db.exec(CREATE_COMMITS_TABLE);
			val = this.db.exec(CREATE_RELATIONS_TABLE);
		}

		public List<string> get_tips(string uuid) {
			var retval = new List<string>();
			return retval;
		}

		public List<string> get_forwards(string uuid, string version) {
			var retval = new List<string>();
			return retval;
		}

		public List<string> get_backwards(string uuid, string version) {
			var retval = new List<string>();
			return retval;
		}
	}
}
