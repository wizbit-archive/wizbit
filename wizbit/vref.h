#ifndef WIZBIT_VREF_H
#define WIZBIT_VREF_H

typedef unsigned char wiz_vref[20];
typedef char wiz_vref_hexbuffer[41];

int wiz_vref_from_hex(wiz_vref vref, const char *hex);
char *wiz_vref_to_hex(const wiz_vref vref, char *buffer);

static inline int wiz_vref_compare(wiz_vref a, wiz_vref b)
{
	return memcmp(a, b, sizeof(wiz_vref));
}

#endif /* WIZBIT_VREF_H */
