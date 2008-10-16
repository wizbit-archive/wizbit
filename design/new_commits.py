import uuid
from pysqlite2 import dbapi2 as sqlite

class Store(object):

    def __init__(self):
        self.db = sqlite.connect(":memory:")
        cursor = self.db.cursor()

        cursor.execute('CREATE TABLE commits (id VARCHAR(50), blob VARCHAR(50))')
        cursor.execute('CREATE TABLE parents (commit_id VARCHAR(50), parent_id VARCHAR(50))')

    def get_tips(self):
        # sql = "SELECT c.* FROM commits AS c WHERE c.id NOT IN (SELECT p.parent_id FROM parents AS p)"
        sql = "SELECT c.id FROM commits AS c LEFT OUTER JOIN parents AS p ON c.id=p.parent_id WHERE p.parent_id IS NULL"
        cursor = self.db.cursor()
        cursor.execute(sql)
        retval = []
        for x in cursor.fetchall():
            retval.append(Commit(self, x[0]))
        return retval

class Commit(object):

    def __init__(self, store, wuid):
        self.store = store
        self.uuid = str(wuid)

    def commit(self):
        cursor = self.store.db.cursor()
        cursor.execute('INSERT INTO commits VALUES (?,?)', (self.uuid, 'someblobdata'))
        for p in self.parents:
            cursor.execute('INSERT INTO parents VALUES (?,?)', (self.uuid, p.uuid))
        self.store.db.commit()

    def forward(self):
        """ Return a list of records that have their parent ids as the current commit """
        sql = "SELECT c.commit_id FROM parents AS c WHERE c.parent_id = ?"
        cursor = self.store.db.cursor()
        cursor.execute(sql, (self.uuid, ))
        retval = []
        for rec in cursor.fetchall():
            retval.append(Commit(self.store, rec[0]))
        return retval

    def previous(self):
        """ Return a list of records for UUIDs in parents.parent_id for the current commit UUID """
        sql = "SELECT c.parent_id FROM parents AS c WHERE c.commit_id = ?"
        cursor = self.store.db.cursor()
        cursor.execute(sql, (self.uuid, ))
        retval = []
        for rec in cursor.fetchall():
            retval.append(Commit(self.store, rec[0]))
        return retval

def make_commit(store, parents):
    commit_id = str(uuid.uuid4())
    cursor = store.db.cursor()
    cursor.execute('INSERT INTO commits VALUES (?,?)', (commit_id, 'someblobdata'))
    for p in parents:
        cursor.execute('INSERT INTO parents VALUES (?,?)', (commit_id, p.uuid))
        store.db.commit()
    return Commit(store, commit_id)

store = Store()
a1 = make_commit(store, [])
a2 = make_commit(store, [a1])
a3 = make_commit(store, [a1])
a4 = make_commit(store, [a2])
a5 = make_commit(store, [a3])

tips = store.get_tips()
assert(len(tips)== 2)

# lets test a merge...
a6 = make_commit(store, [a4, a5])

tips = store.get_tips()
assert(len(tips) == 1)

# lets test iterating that dag
tip = tips[0]
assert(len(tip.forward()) == 0)
assert(len(tip.previous()) == 2)

tips = tip.previous()

assert(tips[0].uuid != tips[1].uuid)
assert(len(tips[0].forward()) == 1)
assert(len(tips[0].previous()) == 1)
assert(len(tips[1].forward()) == 1)
assert(len(tips[1].previous()) == 1)

assert(len(a1.forward()) == 2)
assert(len(a1.previous()) == 0)
