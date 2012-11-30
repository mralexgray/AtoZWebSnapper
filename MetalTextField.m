//
//  MetalTextField.m
//  Paparazzi!
//
//  Created by Wevah on 2005.08.08.
//  Copyright 2005 Derailer. All rights reserved.
//

#import "MetalTextField.h"
#import "MetalTextFieldCell.h"

@implementation MetalTextField

+ (Class)cellClass {
	return [MetalTextFieldCell class];
}

- (void)awakeFromNib {
	NSAttributedString *str = [self attributedStringValue];
	MetalTextFieldCell *cell = [[MetalTextFieldCell alloc] initTextCell:@""];
	[self setCell:cell];
	[self setAttributedStringValue:str];
}

@end
