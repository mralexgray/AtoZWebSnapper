//
//  MetalTextFieldCell.m
//  Paparazzi!
//
//  Created by Wevah on 2005.08.08.
//  Copyright 2005 Derailer. All rights reserved.
//

#import "MetalTextFieldCell.h"


static NSShadow *bevel;

@implementation MetalTextFieldCell

- (id)initTextCell:(NSString *)string {
	self = [super initTextCell:string];
	
	return self;
}

+ (void)initialize {
	if (!bevel) {
		bevel = [[NSShadow alloc] init];
		[bevel setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.5]];
		[bevel setShadowOffset:NSMakeSize(0.0, -1.0)];
	}	
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	[bevel set];
	[super drawInteriorWithFrame:cellFrame inView:controlView];
}

@end
