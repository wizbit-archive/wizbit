using GLib;
using Sqlite;

namespace Wiz {
	internal class CommitStore {
		public string directory { get; construct; }

		private static const string CREATE_COMMITS_TABLE =
			"CREATE TABLE commits(uuid VARCHAR(40), blob VARCHAR(40))";

		private static const string CREATE_RELATIONS_TABLE =
			"CREATE TABLE relations(node_id VARCHAR(40), parent_id VARCHAR(40))";

		private static const string GO_FORWARDS_SQL =
			"SELECT r.commit_id FROM relations AS r WHERE r.parent_id = ?";

		private static const string GO_BACKWARDS_SQL =
			"SELECT r.parent_id FROM relations AS r WHERE r.commit_id = ?";

		private Database db;

		private Statement go_forwards_sql;
		private Statement go_backwards_sql;

		public CommitStore(string directory) {
			this.directory = directory;
		}

		construct {
			/* test and create commits directory */

			Database.open(":memory:", out this.db);

			this.db.prepare(GO_FORWARDS_SQL, -1,
				out this.go_forwards_sql);
			this.db.prepare(GO_BACKWARDS_SQL, -1,
				out this.go_backwards_sql);

			int val = this.db.exec(CREATE_COMMITS_TABLE);
			val = this.db.exec(CREATE_RELATIONS_TABLE);
		}

		public List<string> get_tips(string uuid) {
			var retval = new List<string>();
			return retval;
		}

		public List<string> get_forwards(string uuid, string version) {
			var retval = new List<string>();
			this.go_forwards_sql.reset();
			this.go_forwards_sql.bind_text(1, uuid);
			while (statement.step() == Sqlite.ROW) {
				retval.append("%s".printf(statement.column_text(1)));
			}
			return retval;
		}

		public List<string> get_backwards(string uuid, string version) {
			var retval = new List<string>();
			this.go_backwards_sql.reset();
			this.go_backwards_sql.bind_text(1, uuid);
			while (statement.step() == Sqlite.ROW) {
				retval.append("%s".printf(statement.column_text(1)));
			}
			return retval;
		}
	}
}
