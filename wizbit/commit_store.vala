using GLib;
using Sqlite;

namespace Wiz {
	public class CommitStore : Object {
		public string database { get; construct; }
		public string uuid { get; construct; }

		private static const string GO_FORWARDS_SQL =
			"SELECT r.node_id FROM relations AS r, commits AS c WHERE c.uuid = ? AND r.parent_id=c.id ORDER BY c.timestamp DESC, c.timestamp2 DESC";

		private static const string GO_BACKWARDS_SQL =
			"SELECT r.parent_id FROM relations AS r, commits AS c WHERE c.uuid = ? AND r.node_id=c.id ORDER BY c.timestamp DESC, c.timestamp2 DESC";

		private static const string GET_PRIMARY_TIP_SQL =
			"SELECT c.uuid FROM commits AS c ORDER BY c.timestamp DESC, c.timestamp2 DESC LIMIT 1";

		private static const string GET_TIPS_SQL =
			"SELECT c.uuid FROM commits AS c LEFT OUTER JOIN relations AS r ON c.id=r.parent_id WHERE r.parent_id IS NULL";

		private static const string GET_ROOT_SQL =
			"SELECT c.uuid FROM commits AS c ORDER BY c.timestamp, c.timestamp2 LIMIT 1";

		private static const string INSERT_COMMIT_SQL =
			"INSERT INTO commits (uuid, blob, committer, timestamp, timestamp2) VALUES (?, ?, ?, ?, ?)";

		private static const string INSERT_RELATION_SQL =
			"INSERT INTO relations VALUES ( (SELECT c.id from commits AS c WHERE c.uuid = ?), (SELECT c.id from commits AS c WHERE c.uuid = ?))";

		private static const string SELECT_COMMIT_SQL =
			"SELECT c.blob, c.committer, c.timestamp, c.timestamp2, c.id FROM commits AS c WHERE c.uuid=?";

		private static const string SELECT_COMMIT_BY_ID_SQL = 
			"SELECT c.uuid FROM commits AS c WHERE c.id=? LIMIT 1";

		private static const string SELECT_VERSION_TIMESTAMP_SQL = 
			"SELECT c.timestamp FROM commits AS c WHERE c.uuid = ? LIMIT 1";

		private static const string COUNT_BETWEEN_TIMESTAMPS = 
			"SELECT count(*) FROM commits WHERE timestamp > ? and timestamp < ?";

		private static const string SELECT_RELATION_SQL =
			"SELECT c.uuid FROM commits AS c, relations AS r WHERE r.node_id=? AND c.id==r.parent_id";

		private Database db;

		private Statement go_forwards_sql;
		private Statement go_backwards_sql;
		private Statement get_primary_tip_sql;
		private Statement get_tips_sql;
		private Statement get_root_sql;
		private Statement insert_commit_sql;
		private Statement insert_relation_sql;
		private Statement select_commit_sql;
		private Statement select_commit_by_id_sql;
		private Statement select_version_timestamp_sql;
		private Statement count_between_timestamps_sql;
		private Statement select_relation_sql;

		public CommitStore(string database, string uuid) {
			this.database = database;
			this.uuid = uuid;

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
			this.prepare_statement(SELECT_COMMIT_BY_ID_SQL, out select_commit_by_id_sql);
			this.prepare_statement(SELECT_VERSION_TIMESTAMP_SQL, out select_version_timestamp_sql);
			this.prepare_statement(COUNT_BETWEEN_TIMESTAMPS, out count_between_timestamps_sql);
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
				this.select_commit_by_id_sql.bind_int(1, this.go_forwards_sql.column_int(0));
				this.select_commit_by_id_sql.step();
				retval.append(this.select_commit_by_id_sql.column_text(0));
				this.select_commit_by_id_sql.reset();
				res = this.go_forwards_sql.step();
			}
			assert( res == Sqlite.DONE );
			this.go_forwards_sql.reset();
			return retval;
		}

		public string? get_forward(string version_uuid) {
			this.go_forwards_sql.bind_text(1, version_uuid);
			var res = this.go_forwards_sql.step();
			this.select_commit_by_id_sql.bind_int(1, this.go_forwards_sql.column_int(0));
			this.select_commit_by_id_sql.step();
			var retval = this.select_commit_by_id_sql.column_text(0);
			this.select_commit_by_id_sql.reset();
			this.go_forwards_sql.reset();
			return retval;
		}

		public List<string> get_backwards(string version_uuid) {
			var retval = new List<string>();
			this.go_backwards_sql.bind_text(1, version_uuid);
			var res = this.go_backwards_sql.step();
			while (res == Sqlite.ROW) {
				this.select_commit_by_id_sql.bind_int(1, this.go_backwards_sql.column_int(0));
				this.select_commit_by_id_sql.step();
				retval.append(this.select_commit_by_id_sql.column_text(0));
				this.select_commit_by_id_sql.reset();
				res = this.go_backwards_sql.step();
			}
			assert( res == Sqlite.DONE );
			this.go_backwards_sql.reset();
			return retval;
		}

		public string? get_backward(string version_uuid) {
			this.go_backwards_sql.bind_text(1, version_uuid);
			var res = this.go_backwards_sql.step();
			this.select_commit_by_id_sql.bind_int(1, this.go_backwards_sql.column_int(0));
			this.select_commit_by_id_sql.step();
			var retval = this.select_commit_by_id_sql.column_text(0);
			this.select_commit_by_id_sql.reset();
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

		public int get_timestamp(string version_uuid) {
			this.select_version_timestamp_sql.bind_text(1, version_uuid);
			var res = this.select_version_timestamp_sql.step();
			int retval = this.select_version_timestamp_sql.column_int(0);
			this.select_version_timestamp_sql.reset();
			return retval;
		}

		public int get_commits_between_timestamps(int timestamp1, int timestamp2) {
			// Get the number of commits between these times from the database
			// This is used by the timeline scale to show how dense the timeline is
			this.count_between_timestamps_sql.bind_int(1, timestamp1);
			this.count_between_timestamps_sql.bind_int(2, timestamp2);
			var res = this.count_between_timestamps_sql.step();
			int retval = this.count_between_timestamps_sql.column_int(0);
			this.count_between_timestamps_sql.reset();
			return retval;
		}

		public bool has_commit(string uuid) {
			return (this.lookup_commit(uuid) != null);
		}

		public Commit? lookup_commit(string uuid) {
			var c = new Commit();
			c.uuid = uuid;

			this.select_commit_sql.bind_text(1, uuid);
			var res = this.select_commit_sql.step();

			if (res == Sqlite.DONE)
				return null;

			assert(res == Sqlite.ROW);
			c.blob =this.select_commit_sql.column_text(0);
			c.committer = this.select_commit_sql.column_text(1);
			c.timestamp = this.select_commit_sql.column_int(2);
			c.timestamp2 = this.select_commit_sql.column_int(3);
			int commit_id = this.select_commit_sql.column_int(4);
			this.select_commit_sql.reset();

			this.select_relation_sql.bind_int(1, commit_id);
			res = this.select_relation_sql.step();
			while (res == Sqlite.ROW) {
				c.parents.append(this.select_relation_sql.column_text(0));
				res = this.select_relation_sql.step();
			}
			assert(res == Sqlite.DONE);
			this.select_relation_sql.reset();

			return c;
		}

		public Commit store_commit(Commit c) {
			if (c.uuid == null)
				c.uuid = generate_uuid();

			//var res = this.db.exec("BEGIN");
			//assert(res == Sqlite.OK);

			this.insert_commit_sql.bind_text(1, c.uuid);
			this.insert_commit_sql.bind_text(2, c.blob);
			this.insert_commit_sql.bind_text(3, c.committer);
			this.insert_commit_sql.bind_int(4, c.timestamp);
			this.insert_commit_sql.bind_int(5, c.timestamp2);
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
					"CREATE TABLE commits(id INTEGER PRIMARY KEY, uuid VARCHAR(40), blob VARCHAR(40), committer VARCHAR(256), timestamp INTEGER, timestamp2 INTEGER)");
				this.upgrade_database_step(
					"CREATE TABLE relations(node_id INTEGER, parent_id INTEGER)");
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
}
