//
//  NSStringAdditions.m
//  Paparazzi!
//
//  Created by Wevah on 2005.10.17.
//  Copyright 2005 Derailer. All rights reserved.
//

#import "NSStringAdditions.h"


@implementation NSString (MD5)

- (NSString *)MD5String {
	struct MD5Context ctx;
	const unsigned char *utf8str = [self UTF8String];
	unsigned char digest[16];
	int i;
	unsigned char *md5str;
	NSString *ret = nil;
	
	// Make MD5 hash in hex-string form.
	
	MD5Init(&ctx);
	MD5Update(&ctx, utf8str, strlen(utf8str));
	MD5Final(digest, &ctx);
	
	md5str = malloc(33); // 2 * 16 + 1 for null
	
	for(i = 0; i < 16; i++)
		sprintf(&md5str[i * 2], "%02x", digest[i]);
	
	md5str[32] = '\0';
	
	ret = [NSString stringWithUTF8String:md5str];
	
	free(md5str);
	
	return ret;
}

@end
