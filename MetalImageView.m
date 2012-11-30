//
//  MetalImageView.m
//  Paparazzi!
//
//  Created by Wevah on 2005.08.08.
//  Copyright 2005 Derailer. All rights reserved.
//

#import "MetalImageView.h"
#import "MetalImageCell.h"


static const float kMaxDragImageDimension = 256.0;

@implementation MetalImageView

+ (Class)cellClass {
	return [MetalImageCell class];
}

- (void)awakeFromNib {
	[self setCell:[[MetalImageCell alloc] init]];
}

- (void)copy:(id)sender {
	NSImage *img = [self image];
	
	if (img) {
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		[pb declareTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:self];
		[pb setData:[[self image] TIFFRepresentation] forType:NSTIFFPboardType];
	}
}

- (void)setImage:(NSImage *)anImage {
	[self.enclosingScrollView.documentView setFrame:AZRectFromSize(anImage.size)];
	[super setImage:anImage];
	
	NSSize size = [anImage size];
	
	float width, height;
	
	if (kMaxDragImageDimension > size.width && kMaxDragImageDimension > size.height) {
		width = size.width;
		height = size.height;
	} else {
		float ratio = size.width > size.height ? kMaxDragImageDimension / size.width : kMaxDragImageDimension / size.height;
		width = floorf(ratio * size.width);
		height = floorf(ratio * size.height);
	}
	
	dragImage = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
	[dragImage lockFocus];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[anImage drawInRect:NSMakeRect(0.0, 0.0, width, height) fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.8];
	[dragImage unlockFocus];
}

// Override mouseDown: cos NSImageView does something funky that blocks my mouseDragged:
// Mayhap I'll move to a custom view at some point, since I'm doing my own drawing anyway....
- (void)mouseDown:(NSEvent *)event {
	// nothing
}

- (void)mouseDragged:(NSEvent *)event {
	NSImage *img = [self image];
	
	if (img) {
		NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
		NSPoint p = [event locationInWindow];

		NSSize size = [dragImage size];
		
		p.x -= size.width / 2.0;
		p.y -= size.height / 2.0;
		
		[pb declareTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:self];
		[pb setData:[img TIFFRepresentation] forType:NSTIFFPboardType];
		
		[[self window] dragImage:dragImage at:p offset:NSZeroSize event:event pasteboard:pb source:self slideBack:YES];
	}
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
	if (isLocal)
		return NSDragOperationNone;
	
	return NSDragOperationCopy;
}

- (BOOL)validateMenuItem:(NSMenuItem*)item {
	return  ( ![self image] && [item action] == @selector(copy:))  ? NO : YES;
}

@end
