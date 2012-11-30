//
//  MetalPopUpButtonCell.m
//  Paparazzi!
//
//  Created by Wevah on 2005.08.08.
//  Copyright 2005 Derailer. All rights reserved.
//

#import "MetalPopUpButtonCell.h"


@implementation MetalPopUpButtonCell

- (id)initTextCell: (NSS*) title pullsDown:(BOOL)pullsDown {
	if (self = [super initTextCell:title pullsDown:YES]) {
		[self setUsesItemFromMenu:NO];
		[self setBezelStyle:NSTexturedSquareBezelStyle];
		[self setArrowPosition:NSPopUpNoArrow];
	}
	
	return self;
}

- (void)setImage:(NSImage *)anImage {
	if (anImage) {
		NSMenuItem *item = [[NSMenuItem alloc] init];
		[item setImage:anImage];
		[item setOnStateImage:nil];
		[item setMixedStateImage:nil];
		[self setMenuItem:item];
//		[item release];
	}
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	[[self image] setFlipped:YES];
	[[self image] drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}

@end
