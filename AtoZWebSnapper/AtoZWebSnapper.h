//
//  AtoZWebSnapper.h
//  AtoZWebSnapper
//
//  Created by Alex Gray on 9/14/12.
//
//

#import <Foundation/Foundation.h>
#import "GetURLCommand.h"
#import "NSStringAdditions.h"
#import "MetalImageCell.h"
#import "MetalImageView.h"
#import "MetalPopUpButtonCell.h"
#import "MetalTextField.h"
#import "MetalTextFieldCell.h"

#import "PreferencesController.h"
#import "md5.h"
#import "AtoZWebSnapperWindowController.h"


// Initialized in PaparazziController.h
extern NSString * const kAZWebSnapperFilenameFormatKey;
extern NSString * const kAZWebSnapperThumbnailSuffixKey;
extern NSString * const kAZWebSnapperMaxHistoryKey;
extern NSString * const kAZWebSnapperUseGMTKey;

@interface AtoZWebSnapper : NSObject
@end
