//
//  GetURLCommand.m
//  Paparazzi!
//
//  Created by Wevah on 2005.08.16.
//  Copyright 2005 Derailer. All rights reserved.
//

#import "GetURLCommand.h"
#import "AtoZWebSnapperWindowController.h"

@implementation GetURLCommand

- (id)performDefaultImplementation {	
	NSURL *url = [NSURL URLWithString:[self directParameter]];
	
	if (url) {
		if ([[url scheme] isEqualToString:@"paparazzi"])
			[[AtoZWebSnapperWindowController controller] fetchUsingPaparazziURL:url];
		else
			[[AtoZWebSnapperWindowController controller] fetchUsingString:[url absoluteString]];
	}
	
	return nil;
}

@end
