
class Commit(object):

    def __init__(self, sha1, parents=[]):
        self.sha1 = sha1
        self.blob = "Here is some data\n" + sha1
        self.parents = parents

class Store(object):

    def __init__(self):
        self.store = {}
        self.tips = []

    def has(self, sha1):
        return sha1 in self.store

    def get(self, sha1):
        if self.has(sha1): return self.store[sha1]

    def commit(self, sha1, parents=[]):
        commit = Commit(sha1, parents)
        self.store[sha1] = commit
        return commit

class BreadthFirstIterator(object):

    def __init__(self, store, queue):
        self.store = store
        self.queue = queue[:]
        self.visited = []
        self.is_depleted = False

    def next(self):
        if len(self.queue) == 0:
            return None
        p = self.queue.pop(0)
        while p:
            if p not in self.visited:
                break
            p = self.queue.pop(0)

        if len(self.queue) == 0:
            self.is_depleted = True

        for x in p.parents:
            self.queue.append(x)
        self.visited.append(p)
        return p

    def get(self, size):
        i = size
        retval = []
        while i > 0 and not self.is_depleted:
            retval.append(self.next())
            i -= 1
        return retval

    def kick_out(self, sha_list):
        def _(v):
            for x in self.queue[:]:
                if v.blob == x.blob:
                    for p in v.parents:
                        _(p)
                    self.queue.remove(x)
                    return
        for sha1 in sha_list:
            y = self.store.get(sha1)
            for z in y.parents:
                _(z)

class SyncServer(object):

    def __init__(self, store):
        self.store = store

    def what_do_you_have(self, sha_list):
        retval = []
        for sha1 in sha_list:
            if self.store.has(sha1):
                retval.append(sha1)
        print "i already have: ", retval
        return retval

class SyncClient(object):

    def __init__(self, store):
        self.store = store
        self.iter = BreadthFirstIterator(store, store.tips)

    def sync(self, server):
        while not self.iter.is_depleted:
            sha_list = [x.sha1 for x in self.iter.get(10)]
            print "you can have: ", sha_list
            self.iter.kick_out( server.what_do_you_have(sha_list) )

if __name__ == "__main__":
    a = Store()
    a18 = a.commit("18")
    a17 = a.commit("17")
    a16 = a.commit("16")
    a15 = a.commit("15")
    a14 = a.commit("14")
    a13 = a.commit("13", [a18])
    a12 = a.commit("12", [a17])
    a11 = a.commit("11", [a16])
    a10 = a.commit("10", [a14, a15])
    a9 = a.commit("9", [a10])
    a8 = a.commit("8", [a13])
    a7 = a.commit("7", [a12])
    a6 = a.commit("6", [a9])
    a5 = a.commit("5", [a9])
    a4 = a.commit("4", [a8])
    a3 = a.commit("3", [a7])
    a2 = a.commit("2", [a6])
    a1 = a.commit("1", [a5])
    a.tips = [a1, a2, a3, a4]

    b = Store()
    b16 = b.commit("16")
    b15 = b.commit("15")
    b14 = b.commit("14")
    b11 = b.commit("11", [b16])
    b10 = b.commit("10", [b14, b15])
    b9 = b.commit("9", [b10, b11])
    b6 = b.commit("6", [b9])
    b.tips = [b6]

    bx = SyncServer(b)
    ax = SyncClient(a)
    ax.sync(bx)
