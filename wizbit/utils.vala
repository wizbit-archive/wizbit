internal string generate_uuid() {
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
	return output.str;
}
