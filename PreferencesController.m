//
//  PreferencesController.m
//  Paparazzi!
//
//  Created by Wevah on 2005.08.22.
//  Copyright 2005 Derailer. All rights reserved.
//

#import "PreferencesController.h"
#import "PaparazziDefaultsConstants.h"

static PreferencesController *kController = nil;

@implementation PreferencesController

- (id)initWithWindow:(NSWindow *)window {
	if (!kController && (self = [super initWithWindow:window])) {
		[self setWindowFrameAutosaveName:@"Preferences"];
		kController = self;
	}
	
	return kController;
}

+ (PreferencesController *)controller {
	if (!kController)
		[[PreferencesController alloc] initWithWindowNibName:@"Preferences"];
	
	return kController;
}

- (void)awakeFromNib {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[filenameFormatField setStringValue:[defaults objectForKey:kAZWebSnapperFilenameFormatKey]];
	[maxHistoryField setIntValue:[defaults integerForKey:kAZWebSnapperMaxHistoryKey]];
	[GMTSwitch setState:[defaults boolForKey:kAZWebSnapperUseGMTKey] ? NSOnState : NSOffState];
	[thumbnailSuffixField setStringValue:[defaults objectForKey:kAZWebSnapperThumbnailSuffixKey]];
}

#pragma mark -

- (IBAction)setFilenameFormat:(id)sender {
	[[NSUserDefaults standardUserDefaults] setObject:[sender stringValue] forKey:kAZWebSnapperFilenameFormatKey];
}

- (IBAction)setMaxHistory:(id)sender {
	if (![sender intValue])
		[sender setIntValue:0];
	
	[[NSUserDefaults standardUserDefaults] setInteger:[sender intValue] forKey:kAZWebSnapperMaxHistoryKey];
}

- (IBAction)setUseGMT:(id)sender {
	[[NSUserDefaults standardUserDefaults] setBool:[sender state] == NSOnState forKey:kAZWebSnapperUseGMTKey];
}

- (IBAction)setThumbnailSuffix:(id)sender {
	[[NSUserDefaults standardUserDefaults] setObject:[sender stringValue] forKey:kAZWebSnapperThumbnailSuffixKey];
}

- (void)controlTextDidChange:(NSNotification *)note {
	NSControl *control = [note object];
	NSFormatter *formatter = [control formatter];
	NSText *editor = [[note userInfo] objectForKey:@"NSFieldEditor"];
	
	if (!formatter || [formatter getObjectValue:nil forString:[editor string] errorDescription:nil]) {
		// Don't try to set the default if the formatter says NO, so the field doesn't end editing and clear itself.
		if (control == filenameFormatField)
			[self setFilenameFormat:control];
		if (control == thumbnailSuffixField)
			[self setThumbnailSuffix:control];
		else if (control == maxHistoryField)
			[self setMaxHistory:control];
		else
			NSLog(@"Prefs error.");
	}
}

@end
