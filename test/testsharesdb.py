import tempfile
import sys
import gobject

from wizbit import SharesDatabase, Shares, start_wizbit_server

SHRID = 'e3a361cc-1710-44d3-8582-ac7ff13fd7c0'
DIRID1 = '114a6a70-ff79-4cbb-8b91-6203eaef6afb'
DIRID2 = '94b47f79-53ed-4958-8a01-60bb65feac6d'
DIRID3 = 'f3e3e605-20ed-4200-b061-bfd75351e328'
DIRID4 = 'de92b93d-a274-456a-b484-efb0427beae7'

DIR1 = 'a/test/dir/one'
DIR2 = 'a/test/dir/two'
DIR3 = 'a/test/dir/three'
DIR4 = 'a/test/dir/four'


def main(args):
    tempdir = tempfile.mktemp("wizbit-test")
    shares = Shares(tempdir)

    shares.addShare (DIRID1, SHRID, DIR1);
    shares.addShare (DIRID2, SHRID, DIR2);
    shares.addShare (DIRID3, SHRID, DIR3);
    shares.addShare (DIRID4, SHRID, DIR4);
    start_wizbit_server(shares)

    sdb = SharesDatabase();
    main_loop = gobject.MainLoop()

    try:
        main_loop.run()
    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
    sys.exit(main(sys.argv))
