struct MD5Context {
	unsigned long buf[4];
	unsigned long bits[2];
	unsigned char in[64];
};

void MD5Init(struct MD5Context *);
void MD5Update(struct MD5Context *, const unsigned char *buf, unsigned len);
void MD5Final(unsigned char digest[16], struct MD5Context *ctx);
void Transform(unsigned long buf[4], unsigned long in[16]);
