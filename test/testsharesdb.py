import tempfile
import sys
import gobject
from pprint import pprint
from uuid import uuid4
from wizbit import SharesDatabase, Shares, start_wizbit_server

SHRID = uuid4().hex
DIRID1 = uuid4().hex
DIRID2 = uuid4().hex
DIRID3 = uuid4().hex
DIRID4 = uuid4().hex

DIR1 = 'a/test/dir/one'
DIR2 = 'a/test/dir/two'
DIR3 = 'a/test/dir/three'
DIR4 = 'a/test/dir/four'

def updated(sdb):
    pprint(sdb.shares, width=160)
    print SHRID, sdb.shares.keys()
    assert(sdb.shares.has_key(SHRID))
    assert(sdb.shares[SHRID].has_key(DIRID1))
    assert(sdb.shares[SHRID][DIRID1][3] == DIR1)
    assert(sdb.shares[SHRID].has_key(DIRID2))
    assert(sdb.shares[SHRID][DIRID2][3] == DIR2)
    assert(sdb.shares[SHRID].has_key(DIRID3))
    assert(sdb.shares[SHRID][DIRID3][3] == DIR3)
    assert(sdb.shares[SHRID].has_key(DIRID4))
    assert(sdb.shares[SHRID][DIRID4][3] == DIR4)

def main(args):
    tempdir = tempfile.mktemp("wizbit-test")
    shares = Shares(tempdir)

    shares.addShare (DIRID1, SHRID, DIR1);
    shares.addShare (DIRID2, SHRID, DIR2);
    shares.addShare (DIRID3, SHRID, DIR3);
    shares.addShare (DIRID4, SHRID, DIR4);
    start_wizbit_server(shares)

    sdb = SharesDatabase();
    sdb.connect ("updated", updated)
    main_loop = gobject.MainLoop()

    try:
        main_loop.run()
    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
    sys.exit(main(sys.argv))
