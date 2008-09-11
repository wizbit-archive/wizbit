/* Simple UUID generator 
 *
 * compile with:
 * valac -o test_uuid test_uuid.vala uuid.vapi --Xcc=/usr/lib/libuuid.so 
 *
 * TODO: Integrate this into libwizbit!
 */
using GLib;

public class Test.UUIDGEN : GLib.Object {
    public static void main(string[] args) {
        char[] uuid = new char[16];
        var output = new StringBuilder();
        weak char[] hexstring = (char[]) "0123456789ABCDEF";
        char left;
        char right;
        uuid_generate(uuid);
        for (int i = 0;i <16; i++) {
            left = (uuid[i] >> 4) & 0x0f ;
            right = uuid[i] & 0x0f;
            output.append_c(hexstring[left]);
            output.append_c(hexstring[right]);
        }
        stdout.printf("%s\n", output.str);
    }
}
