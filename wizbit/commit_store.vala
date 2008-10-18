using GLib;
using Sqlite;

namespace Wiz {
	public class CommitStore : Object {
		public string directory { get; construct; }

		private static const string CREATE_COMMITS_TABLE =
			"CREATE TABLE commits(uuid VARCHAR(40), blob VARCHAR(40))";

		private static const string CREATE_RELATIONS_TABLE =
			"CREATE TABLE relations(node_id VARCHAR(40), parent_id VARCHAR(40))";

		private static const string GO_FORWARDS_SQL =
			"SELECT r.node_id FROM relations AS r WHERE r.parent_id = ?";

		private static const string GO_BACKWARDS_SQL =
			"SELECT r.parent_id FROM relations AS r WHERE r.node_id = ?";

		private static const string GET_TIPS_SQL =
			"SELECT c.uuid FROM commits AS c LEFT OUTER JOIN relations AS r ON c.uuid=r.parent_id WHERE r.parent_id IS NULL";

		private static const string INSERT_COMMIT_SQL =
			"INSERT INTO commits VALUES (?, ?)";

		private static const string INSERT_RELATION_SQL =
			"INSERT INTO relations VALUES (?, ?)";

		private static const string SELECT_COMMIT_SQL =
			"SELECT c.blob FROM commits AS c WHERE c.uuid=?";

		private static const string SELECT_RELATION_SQL =
			"SELECT r.parent_id FROM relations AS r WHERE r.node_id=?";

		private Database db;

		private Statement go_forwards_sql;
		private Statement go_backwards_sql;
		private Statement get_tips_sql;
		private Statement insert_commit_sql;
		private Statement insert_relation_sql;
		private Statement select_commit_sql;
		private Statement select_relation_sql;

		public CommitStore(string directory) {
			this.directory = directory;
		}

		construct {
			/* test and create commits directory */

			Database.open(":memory:", out this.db);

			int val = this.db.exec(CREATE_COMMITS_TABLE);
			assert(val == Sqlite.OK);

			val = this.db.exec(CREATE_RELATIONS_TABLE);
			assert(val == Sqlite.OK);

			val = this.db.prepare(GO_FORWARDS_SQL, -1,
				out this.go_forwards_sql);
			assert(val == Sqlite.OK);

			val = this.db.prepare(GO_BACKWARDS_SQL, -1,
				out this.go_backwards_sql);
			assert(val == Sqlite.OK);

			val = this.db.prepare(GET_TIPS_SQL, -1,
				out this.get_tips_sql);
			assert(val == Sqlite.OK);

			val = this.db.prepare(INSERT_COMMIT_SQL, -1,
				out this.insert_commit_sql);
			assert(val == Sqlite.OK);

			val = this.db.prepare(INSERT_RELATION_SQL, -1,
				out this.insert_relation_sql);
			assert(val == Sqlite.OK);

			val = this.db.prepare(SELECT_COMMIT_SQL, -1,
				out this.select_commit_sql);
			assert(val == Sqlite.OK);

			val = this.db.prepare(SELECT_RELATION_SQL, -1,
				out this.select_relation_sql);
			assert(val == Sqlite.OK);
		}

		public List<string> get_tips() {
			var retval = new List<string>();
			this.get_tips_sql.reset();
			var res = this.get_tips_sql.step();
			while (res == Sqlite.ROW) {
				retval.append("%s".printf(this.get_tips_sql.column_text(1)));
				res = this.get_tips_sql.step();
			}
			assert( res == Sqlite.DONE );
			return retval;
		}

		public List<string> get_forwards(string version_uuid) {
			var retval = new List<string>();
			this.go_forwards_sql.reset();
			this.go_forwards_sql.bind_text(1, version_uuid);
			var res = this.go_forwards_sql.step();
			while (res == Sqlite.ROW) {
				retval.append("%s".printf(this.go_forwards_sql.column_text(1)));
				res = this.go_forwards_sql.step();
			}
			assert( res == Sqlite.DONE );
			return retval;
		}

		public List<string> get_backwards(string version_uuid) {
			var retval = new List<string>();
			this.go_backwards_sql.reset();
			this.go_backwards_sql.bind_text(1, version_uuid);
			var res = this.go_backwards_sql.step();
			while (res == Sqlite.ROW) {
				retval.append("%s".printf(this.go_backwards_sql.column_text(1)));
				res = this.go_backwards_sql.step();
			}
			assert( res == Sqlite.DONE );
			return retval;
		}

		public RarCommit lookup_commit(string uuid) {
			var c = new RarCommit();
			c.uuid = uuid;

			this.select_commit_sql.reset();
			this.select_commit_sql.bind_text(1, uuid);
			var res = this.select_commit_sql.step();
			assert(res == Sqlite.ROW);
			c.blob = "%s".printf(this.select_commit_sql.column_text(1));

			this.select_relation_sql.reset();
			this.select_relation_sql.bind_text(1, uuid);
			res = this.select_relation_sql.step();
			while (res == Sqlite.ROW) {
				c.parents.append("%s".printf(this.select_relation_sql.column_text(1)));
				res = this.select_relation_sql.step();
			}
			assert(res == Sqlite.DONE);

			return c;
		}

		public RarCommit store_commit(RarCommit c) {
			c.uuid = generate_uuid();

			this.insert_commit_sql.reset();
			this.insert_commit_sql.bind_text(1, c.uuid);
			this.insert_commit_sql.bind_text(2, c.blob);
			this.insert_commit_sql.step();

			foreach (var p in c.parents) {
				this.insert_relation_sql.reset();
				this.insert_relation_sql.bind_text(1, c.uuid);
				this.insert_relation_sql.bind_text(2, p);
				this.insert_relation_sql.step();
			}

			return c;
		}
	}

	public class RarCommit {
		public string uuid { get; set; }
		public string blob { get; set; }
		public string committer { get; set; }
		public int timestamp { get; set; }

		public List<string> parents;

		construct {
			this.parents = new List<string>();
		}
	}
}
