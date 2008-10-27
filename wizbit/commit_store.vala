using GLib;
using Sqlite;

namespace Wiz {
	public class CommitStore : Object {
		public string database { get; construct; }
		public string uuid { get; construct; }

		private static const string GO_FORWARDS_SQL =
			"SELECT r.node_id FROM relations AS r, commits AS c WHERE r.parent_id = ? AND r.parent_id=c.uuid ORDER BY c.timestamp DESC, c.timestamp2 DESC";

		private static const string GO_BACKWARDS_SQL =
			"SELECT r.parent_id FROM relations AS r, commits AS c WHERE r.node_id = ? AND r.node_id=c.uuid ORDER BY c.timestamp DESC, c.timestamp2 DESC";

		private static const string GET_PRIMARY_TIP_SQL =
			"SELECT c.uuid FROM commits AS c ORDER BY c.timestamp DESC, c.timestamp2 DESC LIMIT 1";

		private static const string GET_TIPS_SQL =
			"SELECT c.uuid FROM commits AS c LEFT OUTER JOIN relations AS r ON c.uuid=r.parent_id WHERE r.parent_id IS NULL";

		private static const string GET_ROOT_SQL =
			"SELECT c.uuid FROM commits AS c ORDER BY c.timestamp, c.timestamp2 LIMIT 1";

		private static const string INSERT_COMMIT_SQL =
			"INSERT INTO commits VALUES (?, ?, ?, ?, null)";

		private static const string INSERT_RELATION_SQL =
			"INSERT INTO relations VALUES (?, ?)";

		private static const string SELECT_COMMIT_SQL =
			"SELECT c.blob, c.committer, c.timestamp FROM commits AS c WHERE c.uuid=?";

		private static const string SELECT_RELATION_SQL =
			"SELECT r.parent_id FROM relations AS r WHERE r.node_id=?";

		private Database db;

		private Statement go_forwards_sql;
		private Statement go_backwards_sql;
		private Statement get_primary_tip_sql;
		private Statement get_tips_sql;
		private Statement get_root_sql;
		private Statement insert_commit_sql;
		private Statement insert_relation_sql;
		private Statement select_commit_sql;
		private Statement select_relation_sql;

		public CommitStore(string database, string uuid) {
			this.database = database;
			this.uuid = uuid;
		}

		construct {
			Database.open(this.database, out this.db);

			this.upgrade_database();

			this.prepare_statement(GO_FORWARDS_SQL, out go_forwards_sql);
			this.prepare_statement(GO_BACKWARDS_SQL, out go_backwards_sql);
			this.prepare_statement(GET_PRIMARY_TIP_SQL, out get_primary_tip_sql);
			this.prepare_statement(GET_TIPS_SQL, out get_tips_sql);
			this.prepare_statement(GET_ROOT_SQL, out get_root_sql);
			this.prepare_statement(INSERT_COMMIT_SQL, out insert_commit_sql);
			this.prepare_statement(INSERT_RELATION_SQL, out insert_relation_sql);
			this.prepare_statement(SELECT_COMMIT_SQL, out select_commit_sql);
			this.prepare_statement(SELECT_RELATION_SQL, out select_relation_sql);
		}

		public string? get_primary_tip() {
			var res = this.get_primary_tip_sql.step();
			if (res == Sqlite.ROW) {
				var tip = this.get_primary_tip_sql.column_text(0);
				this.get_primary_tip_sql.reset();
				return tip;
			}
			assert(res == Sqlite.DONE);
			this.get_primary_tip_sql.reset();
			return null;
		}

		public List<string> get_tips() {
			var retval = new List<string>();
			var res = this.get_tips_sql.step();
			while (res == Sqlite.ROW) {
				retval.append(this.get_tips_sql.column_text(0));
				res = this.get_tips_sql.step();
			}
			assert( res == Sqlite.DONE );
			this.get_tips_sql.reset();
			return retval;
		}

		public List<string> get_forwards(string version_uuid) {
			var retval = new List<string>();
			this.go_forwards_sql.bind_text(1, version_uuid);
			var res = this.go_forwards_sql.step();
			while (res == Sqlite.ROW) {
				retval.append(this.go_forwards_sql.column_text(0));
				res = this.go_forwards_sql.step();
			}
			assert( res == Sqlite.DONE );
			this.go_forwards_sql.reset();
			return retval;
		}

		public string? get_forward(string version_uuid) {
			this.go_forwards_sql.bind_text(1, version_uuid);
			var res = this.go_forwards_sql.step();
			var retval = this.go_forwards_sql.column_text(0);
			this.go_forwards_sql.reset();
			return retval;
		}

		public List<string> get_backwards(string version_uuid) {
			var retval = new List<string>();
			this.go_backwards_sql.bind_text(1, version_uuid);
			var res = this.go_backwards_sql.step();
			while (res == Sqlite.ROW) {
				retval.append(this.go_backwards_sql.column_text(0));
				res = this.go_backwards_sql.step();
			}
			assert( res == Sqlite.DONE );
			this.go_backwards_sql.reset();
			return retval;
		}

		public string? get_backward(string version_uuid) {
			this.go_backwards_sql.bind_text(1, version_uuid);
			var res = this.go_backwards_sql.step();
			var retval = this.go_backwards_sql.column_text(0);
			this.go_backwards_sql.reset();
			return retval;
		}

		public string? get_root() {
			var res = this.get_root_sql.step();
			if (res == Sqlite.ROW) {
				var root = this.get_root_sql.column_text(0);
				this.get_root_sql.reset();
				return root;
			}
			assert(res == Sqlite.DONE);
			this.get_root_sql.reset();
			return null;
		}

		public bool has_commit(string uuid) {
			return (this.lookup_commit(uuid) != null);
		}

		public RarCommit? lookup_commit(string uuid) {
			var c = new RarCommit();
			c.uuid = uuid;

			this.select_commit_sql.bind_text(1, uuid);
			var res = this.select_commit_sql.step();

			if (res == Sqlite.DONE)
				return null;

			assert(res == Sqlite.ROW);
			c.blob =this.select_commit_sql.column_text(0);
			c.committer = this.select_commit_sql.column_text(1);
			c.timestamp = this.select_commit_sql.column_int(2);
			this.select_commit_sql.reset();

			this.select_relation_sql.bind_text(1, uuid);
			res = this.select_relation_sql.step();
			while (res == Sqlite.ROW) {
				c.parents.append(this.select_relation_sql.column_text(0));
				res = this.select_relation_sql.step();
			}
			assert(res == Sqlite.DONE);
			this.select_relation_sql.reset();

			return c;
		}

		public RarCommit store_commit(RarCommit c) {
			c.uuid = generate_uuid();

			//var res = this.db.exec("BEGIN");
			//assert(res == Sqlite.OK);

			this.insert_commit_sql.bind_text(1, c.uuid);
			this.insert_commit_sql.bind_text(2, c.blob);
			this.insert_commit_sql.bind_text(3, c.committer);
			this.insert_commit_sql.bind_int(4, c.timestamp);
			var res = this.insert_commit_sql.step();
			assert(res == Sqlite.DONE);

			this.insert_commit_sql.reset();

			foreach (var p in c.parents) {
				this.insert_relation_sql.bind_text(1, c.uuid);
				this.insert_relation_sql.bind_text(2, p);
				res = this.insert_relation_sql.step();
				assert(res == Sqlite.DONE);

				this.insert_relation_sql.reset();
			}

			//res = this.db.exec("END");
			//debug(this.db.errmsg());
			//assert(res == Sqlite.OK);

			return c;
		}

		private void prepare_statement(string sql, out Statement stmt) {
			var result = this.db.prepare(sql, -1, out stmt);
			if (result != Sqlite.OK)
				critical("FAILED on '%s'\n%u: %s (%u)\n", sql, result, this.db.errmsg(), this.db.errcode());
		}

		private void upgrade_database() {
			uint version = this.check_database_version();

			if (version <= 0) {
				// upgrade version 0 to version 1
				this.upgrade_database_step(
					"CREATE TABLE commits(uuid VARCHAR(40), blob VARCHAR(40), committer VARCHAR(256), timestamp INTEGER, timestamp2 INTEGER PRIMARY KEY)");
				this.upgrade_database_step(
					"CREATE TABLE relations(node_id VARCHAR(40), parent_id VARCHAR(40))");
			}

			if (version <= 1) {
				// upgrade version 1 to version 2
			}
		}

		private uint check_database_version() {
			Statement tmp;

			this.db.prepare("SELECT tbl_name FROM sqlite_master",
				-1, out tmp);

			tmp.reset();
			if (tmp.step() == Sqlite.DONE)
				return 0;

			return 1;
		}

		private void upgrade_database_step(string sql) {
			Statement tmp;
			this.db.prepare(sql, -1, out tmp);
			tmp.reset();
			int res = tmp.step();
			assert(res == Sqlite.DONE);
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
