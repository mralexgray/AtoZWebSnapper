// Copyright (C) 2004-2005 Nate Weaver (Wevah)
// (based on original work by Johan Sørensen)
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

#import "AtoZWebSnapperWindowController.h"
#import "PreferencesController.h"
#import "MetalImageCell.h"
#import "NSStringAdditions.h"

static NSString * const kAZWebSnapperUserAgent = @"Paparazzi!/0.3";

static NSString * const kAZWebSnapperWebMinWidthKey		= @"WebMinWidth";
static NSString * const kAZWebSnapperWebMinHeightKey		= @"WebMinHeight";
static NSString * const kAZWebSnapperWebMaxWidthKey		= @"WebMaxWidth";
static NSString * const kAZWebSnapperWebMaxHeightKey		= @"WebMaxHeight";
static NSString * const kAZWebSnapperSaveFormatKey			= @"SaveFormat";
static NSString * const kAZWebSnapperJPEGQualityKey		= @"JPEGQuality";
static NSString * const kAZWebSnapperURLHistoryKey			= @"URLHistory";

static NSString * const kAZWebSnapperThumbnailScaleKey		= @"ThumbnailScale";
static NSString * const kAZWebSnapperSaveImageKey			= @"SaveImage";
static NSString * const kAZWebSnapperSaveThumbnailKey		= @"SaveThumbnail";
static NSString * const kAZWebSnapperDelayKey				= @"Delay";
static NSString * const kAZWebSnapperThumbnailFormatKey	= @"ThumbnailFormat";



static AtoZWebSnapperWindowController *kController = nil;

@interface WebPreferences (StuffThatShouldBeInTheHeadersButIsNot)

- (void)setShouldPrintBackgrounds:(BOOL)yesno;

@end

@interface WebView (StuffThatShouldBeInTheHeadersButIsNot)

- (void)setMediaStyle:(NSString *)mediaStyle;

@end

@interface AtoZWebSnapperWindowController (Private)

- (void)takeURLFromBrowser:(NSString *)name;
- (void)takeScreenshot;

- (void)fetchUsingString:(NSString *)string minSize:(NSSize)minSize cropSize:(NSSize)cropSize;

- (NSString *)filenameWithFormat:(NSString *)format;
- (void)saveAsPNG:(NSString *)filename fullSize:(BOOL)saveFullSize thumbnailScale:(float)thumbnailScale thumbnailSuffix:(NSString *)thumbnailSuffix;
- (void)saveAsTIFF:(NSString *)filename fullSize:(BOOL)saveFullSize thumbnailScale:(float)thumbnailScale thumbnailSuffix:(NSString *)thumbnailSuffix;
- (void)saveAsJPEG:(NSString *)filename usingCompressionFactor:(float)factor fullSize:(BOOL)saveFullSize thumbnailScale:(float)thumbnailScale thumbnailSuffix:(NSString *)thumbnailSuffix;
- (void)saveAsPDF:(NSString *)filename;
- (NSBitmapImageRep *)bitmapThumbnailWithScale:(float)scale;

- (void)validateInputSchemeForControl:(NSControl *)control;

- (void)warnOfMalformedPaparazziURL:(NSURL *)url;

- (void)addURLToHistory:(NSURL *)url;
- (NSMenu *)historyMenu;
- (NSMenu *)captureFromMenu;

@end

#pragma mark -

@implementation AtoZWebSnapperWindowController

- (id)initWithWindow:(NSWindow *)window {
	if (self = [super initWithWindow:window]) {
		webWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-16000.0, -16000.0, 100.0, 100.0) styleMask:NSBorderlessWindowMask backing:NSBackingStoreRetained defer:NO];		
		webView = [[WebView alloc] initWithFrame:NSMakeRect(-16000.0, -16000.0, 100.0, 100.0)];
		[webView setFrameLoadDelegate:self];
		[webView setResourceLoadDelegate:self];
		[webView setApplicationNameForUserAgent:kAZWebSnapperUserAgent];
		[webView setMaintainsBackForwardList:NO];
		
		if ([webView respondsToSelector:@selector(setMediaStyle:)])
			[webView setMediaStyle:@"screen"]; // We want PDFs to look like the screen render. 10.3.9+
		
		WebPreferences *webPrefs = [WebPreferences standardPreferences];
		
		//if ([webPrefs respondsToSelector:@selector(setShouldPrintBackgrounds:)])
		//	[webPrefs setShouldPrintBackgrounds:YES];
		
		[webPrefs setJavaScriptCanOpenWindowsAutomatically:NO]; // That would suck.
		[webPrefs setAllowsAnimatedImages:NO];
		
		// remove scrollbars, so the content is x wide and not x - 15
		[[[webView mainFrame] frameView] setAllowsScrolling:NO];
		
		[webWindow setContentView:webView];
		
		// Register notifications
		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		[center addObserver:self selector:@selector(webViewProgressStarted:) name:WebViewProgressStartedNotification object:webView];
		[center addObserver:self selector:@selector(webViewProgressEstimateChanged:) name:WebViewProgressEstimateChangedNotification object:webView];
		[center addObserver:self selector:@selector(webViewProgressFinished:) name:WebViewProgressFinishedNotification object:webView];
		
		[self setWindowFrameAutosaveName:@"MainWindow"];
		
		history = [[[NSUserDefaults standardUserDefaults] objectForKey:kAZWebSnapperURLHistoryKey] mutableCopy];
		
		kController = self;
	}
	
	return self;
}

+ (void)initialize {
	NSDictionary *defaultDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedInt:800],	kAZWebSnapperWebMinWidthKey,
		[NSNumber numberWithUnsignedInt:600],	kAZWebSnapperWebMinHeightKey,
		[NSNumber numberWithUnsignedInt:0],		kAZWebSnapperWebMaxWidthKey,
		[NSNumber numberWithUnsignedInt:0],		kAZWebSnapperWebMaxHeightKey,
		@"PNG",									kAZWebSnapperSaveFormatKey,
		[NSNumber numberWithFloat:0.8],			kAZWebSnapperJPEGQualityKey,
		@"%t (%y%m%d)",							kAZWebSnapperFilenameFormatKey,
		@"-thumb",								kAZWebSnapperThumbnailSuffixKey,
		[NSArray array],						kAZWebSnapperURLHistoryKey,
		[NSNumber numberWithUnsignedInt:10],	kAZWebSnapperMaxHistoryKey,
		[NSNumber numberWithBool:NO],			kAZWebSnapperUseGMTKey,
		[NSNumber numberWithFloat:0.25],		kAZWebSnapperThumbnailScaleKey,
		[NSNumber numberWithBool:YES],			kAZWebSnapperSaveImageKey,
		[NSNumber numberWithBool:NO],			kAZWebSnapperSaveThumbnailKey,
		[NSNumber numberWithFloat:0.0],			kAZWebSnapperDelayKey,
		@"PNG",									kAZWebSnapperThumbnailFormatKey,
		nil];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultDefaults];
}

+ (AtoZWebSnapperWindowController *)controller {
	return kController;
}

- (void)awakeFromNib {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[[self window] registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, NSFilenamesPboardType, nil]];
	[imageView unregisterDraggedTypes];
	
	[urlField setStringValue:[history count] ? [history objectAtIndex:0] : @"http://"];
	[openRecentMenuItem setSubmenu:[self historyMenu]];
	[urlField noteNumberOfItemsChanged];
	
	unsigned maxWidth = [defaults integerForKey:kAZWebSnapperWebMaxWidthKey];
	unsigned maxHeight = [defaults integerForKey:kAZWebSnapperWebMaxHeightKey];
	
	[minWidthField setIntValue:[defaults integerForKey:kAZWebSnapperWebMinWidthKey]];
	[minHeightField setIntValue:[defaults integerForKey:kAZWebSnapperWebMinHeightKey]];
	
	if (maxWidth)
		[maxWidthField setIntValue:maxWidth];
	if (maxHeight)
		[maxHeightField setIntValue:maxHeight];
	
	[delayField setFloatValue:[defaults floatForKey:kAZWebSnapperDelayKey]];

	[[self window] setExcludedFromWindowsMenu:YES];
	
	[[captureFromMenuItem submenu] setDelegate:self];
	
#if 0
	[scriptMenuItem setTitle:@""];
	[scriptMenuItem setImage:[NSImage imageNamed:@"scriptMenu"]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(popUpButtonWillPopUp:) name:NSPopUpButtonWillPopUpNotification object:takeURLFromPopUp];
	
	NSImage *image = [takeURLFromPopUp image];
	[takeURLFromPopUp setCell:[[[MetalPopUpButtonCell alloc] init] autorelease]];
	[takeURLFromPopUp setImage:image];
#endif
}

- (IBAction)fetch:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSSize newSize = NSMakeSize([minWidthField floatValue], [minHeightField floatValue]);
	NSURL *url = [NSURL URLWithString:[urlField stringValue]];
	currentMax = NSMakeSize([maxWidthField floatValue], [maxHeightField floatValue]);
	currentDelay = [delayField floatValue];
	
	[defaults setInteger:[minWidthField intValue] forKey:kAZWebSnapperWebMinWidthKey];
	[defaults setInteger:[minHeightField intValue] forKey:kAZWebSnapperWebMinHeightKey];
	[defaults setInteger:[maxWidthField intValue] forKey:kAZWebSnapperWebMaxWidthKey];
	[defaults setInteger:[maxHeightField intValue] forKey:kAZWebSnapperWebMaxHeightKey];
	[defaults setFloat:currentDelay forKey:kAZWebSnapperDelayKey];

	[webWindow setContentSize:newSize];
	
	[webView setFrameSize:newSize];
	
	[self validateInputSchemeForControl:urlField];
		
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
}

- (IBAction)urlFieldEnter:(id)sender {
	[captureCancelButton performClick:sender];
}

- (void)cancel:(id)sender {
	[webView stopLoading:sender];
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {	
	if ([error code] != -999) { // Don't show the sheet if the user cancelled.
		// what happens of something goes wrong while loading url (dns error etc)
		
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"LoadErrorTitle", nil), [urlField stringValue]]];
		[alert setInformativeText:[error localizedDescription]];
		[alert setAlertStyle:NSWarningAlertStyle];	
		
		[alert beginSheetModalForWindow:[NSApp mainWindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	// we don't really need to do anything here after the user has clicked 'ok' to the alert
	// other than releasing the object of course
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {	
	if (frame == [sender mainFrame]) {
		WebDataSource *dataSource = [frame dataSource];
		currentURL = [[dataSource request] URL];
		
		[self addURLToHistory:currentURL];
		[urlField setStringValue:[currentURL absoluteString]];
		[urlField noteNumberOfItemsChanged];
		
		currentTitle = [dataSource pageTitle];
		[[self window] setTitle:[@"Paparazzi!: " stringByAppendingString:currentTitle]];
		
		// set the size to the natural contents of the page
		NSView *viewport = [[[webView mainFrame] frameView] documentView]; // width/height of html page
		NSWindow *viewportWindow = [viewport window];
		NSRect viewportBounds = [viewport bounds];
		
		[viewportWindow display];
		[viewportWindow setContentSize:viewportBounds.size];
		[viewport setFrame:viewportBounds];
		
		//[self takeScreenshot];
		[self performSelector:@selector(takeScreenshot) withObject:nil afterDelay:currentDelay]; // allow snapping of Flash sites. XXX make user-definable!
		
		[saveButton setEnabled:YES];
		[pageLoadProgress setHidden:YES];
	}
}

- (void)webViewProgressStarted:(NSNotification *)notification {	
	isLoading = YES;

	[NSObject cancelPreviousPerformRequestsWithTarget:self]; // stop pending captures
	
	[captureCancelButton setTitle:NSLocalizedString(@"Cancel", nil)];
	[captureCancelButton setAction:@selector(cancel:)];
	
	[pageLoadProgress setHidden:NO];
	[pageLoadProgress setDoubleValue:0.0];
}

- (void)webViewProgressEstimateChanged:(NSNotification *)notification {
	[pageLoadProgress setDoubleValue:[webView estimatedProgress]];
}

- (void)webViewProgressFinished:(NSNotification *)notification {	
	isLoading = NO;
	
	[pageLoadProgress setHidden:YES];
	
	[captureCancelButton setTitle:[NSLocalizedString(@"Capture", nil) stringByAppendingString:@"!"]];
	[captureCancelButton setAction:@selector(fetch:)];
}

#pragma mark -

- (void)takeScreenshot {
	NSView *viewport = [[[webView mainFrame] frameView] documentView]; // width/height of html page
	NSRect viewportBounds = [viewport bounds];
	
	float cropHeight = currentMax.height ? MIN(currentMax.height, viewportBounds.size.height) : viewportBounds.size.height;
		
	NSRect cropBounds = NSMakeRect(0.0, viewportBounds.size.height - cropHeight,
							 currentMax.width ? MIN(currentMax.width, viewportBounds.size.width) : viewportBounds.size.width,
							 cropHeight);	

	// take the screenshot
	[webView lockFocus];
	bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:cropBounds];
	[webView unlockFocus];
	
	pdfData = [webView dataWithPDFInsideRect:cropBounds];
	NSImage *dispImage = [[NSImage alloc] initWithData:[bitmap TIFFRepresentation]];
	
	// Display the image
	[imageView setImage:dispImage];
	[previewField setStringValue:[NSString stringWithFormat:@"Preview (%u %C %u):", [bitmap pixelsWide], 0x00d7, [bitmap pixelsHigh]]]; // 0x00d7 = multiplication sign
}

#pragma mark -
#pragma mark Save

- (IBAction)saveDocumentAs:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	// figure out a suitable string for the filename
	//NSString *host = [currentURL host];
	//NSMutableString *suggestedFileName = [NSMutableString stringWithFormat:@"%@%@", host ? host : @"", [currentURL path]];
	NSMutableString *suggestedFileName = [NSMutableString stringWithString:[self filenameWithFormat:[defaults objectForKey:kAZWebSnapperFilenameFormatKey]]];
	
	// Replace path delmiters
	[suggestedFileName replaceOccurrencesOfString:@"/" withString:@"-" options:NSLiteralSearch range:NSMakeRange(0, [suggestedFileName length])];
	[suggestedFileName replaceOccurrencesOfString:@":" withString:@"-" options:NSLiteralSearch range:NSMakeRange(0, [suggestedFileName length])];
	
	savePanel = [NSSavePanel savePanel];
	[savePanel setCanSelectHiddenExtension:YES];
	
	NSString *saveFormat = [defaults objectForKey:kAZWebSnapperSaveFormatKey];
	
	if ([fileFormatPopUp indexOfItemWithTitle:saveFormat] != -1)
		[fileFormatPopUp selectItemWithTitle:saveFormat];
	else
		[fileFormatPopUp selectItemWithTitle:@"PNG"];
	
	BOOL saveThumbnail = [defaults boolForKey:kAZWebSnapperSaveThumbnailKey];
	BOOL saveImage = [defaults boolForKey:kAZWebSnapperSaveImageKey];
	
	[saveThumbnailSwitch setState:saveThumbnail ? NSOnState : NSOffState];
	[thumbnailScaleField setEnabled:saveThumbnail];

	[saveImageSwitch setState:saveImage ? NSOnState : NSOffState];

	[qualitySlider setFloatValue:[[defaults objectForKey:kAZWebSnapperJPEGQualityKey] floatValue]];
	[self setFileFormat:fileFormatPopUp]; // Also sets the required file type.
	[savePanel setAccessoryView:accessoryView];
	[savePanel beginSheetForDirectory:nil file:suggestedFileName modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSOKButton) {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *fileType = [[fileFormatPopUp selectedItem] title];
		float quality = [qualitySlider floatValue];
		NSString *filename = [sheet filename];
		
		BOOL saveImage = [saveImageSwitch state] == NSOnState;
		float thumbnailScale = 0.0;
		NSString *thumbnailSuffix = nil;
		
		BOOL saveThumbnail = [saveThumbnailSwitch state] == NSOnState;
		
		if (saveThumbnail) {
			thumbnailScale = [thumbnailScaleField floatValue];
			thumbnailSuffix = [defaults objectForKey:kAZWebSnapperThumbnailSuffixKey];
		}
					
		if ([fileType isEqualToString:@"PNG"])
			[self saveAsPNG:filename fullSize:saveImage thumbnailScale:thumbnailScale thumbnailSuffix:thumbnailSuffix];
		else if ([fileType isEqualToString:@"TIFF"])
			[self saveAsTIFF:filename fullSize:saveImage thumbnailScale:thumbnailScale thumbnailSuffix:thumbnailSuffix];
		else if ([fileType isEqualToString:@"JPEG"])
			[self saveAsJPEG:filename usingCompressionFactor:quality fullSize:saveImage thumbnailScale:thumbnailScale thumbnailSuffix:thumbnailSuffix];
		else if ([fileType isEqualToString:@"PDF"]) {
			[self saveAsPDF:filename];
		} else
			NSLog(@"Bad file format: %@", fileType);
				
		[defaults setObject:fileType forKey:kAZWebSnapperSaveFormatKey];
		[defaults setFloat:quality forKey:kAZWebSnapperJPEGQualityKey];
		[defaults setFloat:thumbnailScale forKey:kAZWebSnapperThumbnailScaleKey];
		[defaults setBool:saveImage forKey:kAZWebSnapperSaveImageKey];
		[defaults setBool:saveThumbnail forKey:kAZWebSnapperSaveThumbnailKey];
		
		savePanel = nil;
	}
}

- (IBAction)setFileFormat:(id)sender {
	if (savePanel) {
		NSString *fileType = [[sender selectedItem] title];
	
		if ([fileType isEqualToString:@"PNG"]) {
			[savePanel setRequiredFileType:@"png"];
			[qualitySlider setEnabled:NO];
			[saveThumbnailSwitch setEnabled:YES];
			[saveImageSwitch setEnabled:YES];
		} else if ([fileType isEqualToString:@"TIFF"]) {
			[savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"tiff", @"tif", nil]];
			[qualitySlider setEnabled:NO];
			[saveThumbnailSwitch setEnabled:YES];
			[saveImageSwitch setEnabled:YES];
		} else if ([fileType isEqualToString:@"JPEG"]) {
			[savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"jpg", @"jpeg", @"jpe", nil]];
			[qualitySlider setEnabled:YES];
			[saveThumbnailSwitch setEnabled:YES];
			[saveImageSwitch setEnabled:YES];
		} else if ([fileType isEqualToString:@"PDF"]) {
			[savePanel setRequiredFileType:@"pdf"];
			[qualitySlider setEnabled:NO];
			
			[saveThumbnailSwitch setEnabled:NO];
			[saveThumbnailSwitch setState:NSOffState];
			[saveImageSwitch setEnabled:NO];
			[saveImageSwitch setState:NSOnState];
			[thumbnailScaleField setEnabled:NO];
		} else
			NSLog(@"Bad file format!");
	}
}

- (NSString *)filenameWithFormat:(NSString *)format {
	NSMutableString *str = [NSMutableString stringWithCapacity:128];
	
	if (format) {
		unsigned i = 0, len = [format length];
		NSCalendarDate *now = [NSCalendarDate calendarDate];
		
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:kAZWebSnapperUseGMTKey] boolValue])
			[now setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
				
		NSString *key, *rep;
		
		NSString *host = [currentURL host];
		
		if (!host)
			host = @"localhost";
				
		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
			currentTitle,							@"%t",
			[currentURL absoluteString],			@"%u",
			[[currentURL path] lastPathComponent],	@"%f",
			host,									@"%h",
			[NSString stringWithFormat:@"%u", [now yearOfCommonEra]],	@"%y",
			[NSString stringWithFormat:@"%02u", [now monthOfYear]],		@"%m",
			[NSString stringWithFormat:@"%02u", [now dayOfMonth]],		@"%d",
			[NSString stringWithFormat:@"%02u", [now hourOfDay]],		@"%H",
			[NSString stringWithFormat:@"%02u", [now minuteOfHour]],	@"%M",
			[[now timeZone] abbreviation],				@"%Z",
			[[currentURL absoluteString] MD5String],	@"%5",
			@"%", @"%%",
			nil];
		
		for (i = 0; i < len; ++i) {
			unichar c = [format characterAtIndex:i];
			
			if (c == '%') {
				if (i < len - 1) {
					key = [format substringWithRange:NSMakeRange(i, 2)];
					rep = [dict objectForKey:key];
					
					if (rep) {						
						[str appendString:rep];
					} else
						[str appendString:@""];
					
					++i;
				}
			} else
				[str appendFormat:@"%C", c];
		}
	}
	
	return [NSString stringWithString:str];
}

- (void)saveAsPNG:(NSString *)filename fullSize:(BOOL)saveFullSize thumbnailScale:(float)thumbnailScale thumbnailSuffix:(NSString *)thumbnailSuffix {
	if (filename) {
		if (saveFullSize)
			[[bitmap representationUsingType:NSPNGFileType properties:nil] writeToFile:filename atomically:YES];
		
		if (thumbnailScale > 0.0001 && [thumbnailSuffix length]) {
			NSString *thumbName = [NSString stringWithFormat:@"%@%@.%@", [filename stringByDeletingPathExtension], thumbnailSuffix, [filename pathExtension]];
			NSBitmapImageRep *thumb = [self bitmapThumbnailWithScale:thumbnailScale];
			[[thumb representationUsingType:NSPNGFileType properties:nil] writeToFile:thumbName atomically:YES];
		}
	}
}

- (void)saveAsTIFF:(NSString *)filename fullSize:(BOOL)saveFullSize thumbnailScale:(float)thumbnailScale thumbnailSuffix:(NSString *)thumbnailSuffix {
	if (filename) {		
		if (saveFullSize)
			[[bitmap TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0] writeToFile:filename atomically:YES];
		
		if (thumbnailScale > 0.0001 && [thumbnailSuffix length]) {
			NSString *thumbName = [NSString stringWithFormat:@"%@%@.%@", [filename stringByDeletingPathExtension], thumbnailSuffix, [filename pathExtension]];
			NSBitmapImageRep *thumb = [self bitmapThumbnailWithScale:thumbnailScale];
			[[thumb TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0] writeToFile:thumbName atomically:YES];
		}
	}
}

- (void)saveAsJPEG:(NSString *)filename usingCompressionFactor:(float)factor fullSize:(BOOL)saveFullSize thumbnailScale:(float)thumbnailScale thumbnailSuffix:(NSString *)thumbnailSuffix {
	if (filename) {		
		if (saveFullSize)
			[[bitmap representationUsingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:factor] forKey:NSImageCompressionFactor]] writeToFile:filename atomically:YES];
		
		if (thumbnailScale > 0.0001 && [thumbnailSuffix length]) {
			NSString *thumbName = [NSString stringWithFormat:@"%@%@.%@", [filename stringByDeletingPathExtension], thumbnailSuffix, [filename pathExtension]];
			NSBitmapImageRep *thumb = [self bitmapThumbnailWithScale:thumbnailScale];
			[[thumb representationUsingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:factor] forKey:NSImageCompressionFactor]] writeToFile:thumbName atomically:YES];
		}
	}
}

- (void)saveAsPDF:(NSString *)filename {
	[pdfData writeToFile:filename atomically:YES];
}

- (NSBitmapImageRep *)bitmapThumbnailWithScale:(float)scale {
	float width = rintf((float)[bitmap pixelsWide] * scale);
	float height = rintf((float)[bitmap pixelsHigh] * scale);
	NSRect thumbRect = NSMakeRect(0.0, 0.0, width, height);
	NSSize size = NSMakeSize(width, height);
	NSImage *img = [[NSImage alloc] initWithSize:size];
	NSBitmapImageRep *rep;
	[img lockFocus];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[bitmap drawInRect:thumbRect];
	rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:thumbRect];
	[img unlockFocus];
	return rep;
}

- (IBAction)toggleSaveThumbnail:(id)sender {
	[thumbnailScaleField setEnabled:[sender state] == NSOnState];
}

#pragma mark -

- (void)openDocument:(id)sender {
	[self showWindow:sender];
	[[self window] makeFirstResponder:urlField];
}

#pragma mark -
#pragma mark URL History

- (void)addURLToHistory:(NSURL *)url {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	unsigned max = [[defaults objectForKey:kAZWebSnapperMaxHistoryKey] unsignedIntValue];
	NSString *urlString = [url absoluteString];
	
	if ([history containsObject:urlString])
		[history removeObject:urlString];
	else if ([history count] > max)
		[history removeObjectAtIndex:max - 1];
	
	[history insertObject:urlString atIndex:0];
	[urlField setNumberOfVisibleItems:MIN(10, [history count])];
	[defaults setObject:history forKey:kAZWebSnapperURLHistoryKey];
	[openRecentMenuItem setSubmenu:[self historyMenu]];
}

- (void)clearRecentDocuments:(id)sender {
	[history removeAllObjects];
	[urlField noteNumberOfItemsChanged];
	[openRecentMenuItem setSubmenu:[self historyMenu]];
	[[NSUserDefaults standardUserDefaults] setObject:history forKey:kAZWebSnapperURLHistoryKey];
}

- (NSMenu *)historyMenu {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"History"];
	
	if ([history count]) {NSEnumerator *histEnum = [history objectEnumerator];
		NSString *urlString;
		
		while (urlString = [histEnum nextObject]) {
			[menu addItemWithTitle:urlString action:@selector(fetchWithMenuItem:) keyEquivalent:@""];
		}
		
		[menu addItem:[NSMenuItem separatorItem]];
	}
	
	[menu addItemWithTitle:NSLocalizedString(@"ClearMenu", nil) action:@selector(clearRecentDocuments:) keyEquivalent:@""];
	
	return menu;
}

- (void)fetchWithMenuItem:(id)sender {
	[self fetchUsingString:[sender title]];
}

#pragma mark -

- (void)warnOfMalformedPaparazziURL:(NSURL *)url {
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:NSLocalizedString(@"MalformedURLTitle", nil)];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"MalformedURLText", nil), [url absoluteString]]];
	[alert setAlertStyle:NSWarningAlertStyle];	
	
	[alert beginSheetModalForWindow:[NSApp mainWindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];	
}

- (void)fetchUsingPaparazziURL:(NSURL *)url {
	if (url && [[url scheme] isEqualToString:@"paparazzi"]) {
		NSString *resource = [url resourceSpecifier];
		
		if ([resource hasPrefix:@"("]) { // has params
			unsigned lastparen = [resource rangeOfString:@")"].location;
			
			if (lastparen != NSNotFound) {
				unsigned width = 0;
				unsigned height = 0;
				int cropWidth = -1;
				int cropHeight = -1;
				
				NSString *params = [[[resource substringWithRange:NSMakeRange(1, lastparen - 1)] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] lowercaseString];
				
				NSArray *keyValuePairs = [params componentsSeparatedByString:@","];
				NSEnumerator *e = [keyValuePairs objectEnumerator];
				NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
				NSString *pair;
				
				while (pair = [[e nextObject] stringByTrimmingCharactersInSet:whitespace]) {
					NSArray *keyValue = [pair componentsSeparatedByString:@"="];
					
					NSString *key = [[keyValue objectAtIndex:0] stringByTrimmingCharactersInSet:whitespace];
					NSString *value = nil;
					
					if ([keyValue count] == 2)
						value = [[keyValue objectAtIndex:1] stringByTrimmingCharactersInSet:whitespace];
															
					if (key) {
						if (value) {
							if ([key isEqualToString:@"width"] || [key isEqualToString:@"minwidth"])
								width = [value intValue];
							else if ([key isEqualToString:@"height"] || [key isEqualToString:@"minheight"])
								height = [value intValue];
							else if ([key isEqualToString:@"cropwidth"] || [key isEqualToString:@"maxwidth"])
								cropWidth = [value intValue];
							else if ([key isEqualToString:@"cropheight"] || [key isEqualToString:@"maxheight"])
								cropHeight = [value intValue];
						}
						
						if ([key isEqualToString:@"nocrop"])
							cropWidth = cropHeight = 0;
					}
				}
				
				url = [NSURL URLWithString:[resource substringWithRange:NSMakeRange(lastparen + 1, [resource length] - lastparen - 1)]];
				
				if (url)
					[self fetchUsingString:[url absoluteString] minSize:NSMakeSize(width, height) cropSize:NSMakeSize(cropWidth, cropHeight)];
			} else {
				[self warnOfMalformedPaparazziURL:url];
			}
		} else { // no params
			url = [NSURL URLWithString:resource];
			
			if (url)
				[self fetchUsingString:[url absoluteString]];
		}
	} else // Pass http/https/file URLs on.
		[self fetchUsingString:[url absoluteString]];
}

- (void)fetchUsingString:(NSString *)string {
	if (string) {
		[NSApp activateIgnoringOtherApps:YES];
		[self showWindow:nil];
		[urlField setStringValue:string];
		[self fetch:nil];
	}
}

- (void)fetchUsingString:(NSString *)string minSize:(NSSize)minSize cropSize:(NSSize)cropSize {
	if (minSize.width > 0.0)
		[minWidthField setIntValue:minSize.width];	
	if (minSize.height > 0.0)
		[minHeightField setIntValue:minSize.height];
	if (cropSize.width > -0.5) {
		if (cropSize.width == 0.0)
			[maxWidthField setStringValue:@""];
		else
			[maxWidthField setIntValue:cropSize.width];
	}
	
	if (cropSize.height > -0.5) {
		if (cropSize.height == 0.0)
			[maxHeightField setStringValue:@""];
		else
			[maxHeightField setIntValue:cropSize.height];
	}
	
	[self fetchUsingString:string];
}

- (void)takeURLFromBrowser:(NSString *)name {
	NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"scpt" inDirectory:@"Take URL From"];
		
	if (path) {
		NSDictionary *err = nil;
		NSAppleScript *as = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&err];
		if (err)
			NSLog(@"%@", err);		
		NSAppleEventDescriptor *aed = [as executeAndReturnError:&err];
		if (err)
			NSLog(@"%@", err);
		
		if (!err)
			[self fetchUsingString:[aed stringValue]];
	}
}

- (IBAction)takeURLFromMyBrowser:(id)sender {
	NSString *title = [sender title];
	
	if ([title rangeOfString:@"Camino"].location != NSNotFound)
		[self takeURLFromBrowser:@"Camino"];
	else if ([title rangeOfString:@"Safari"].location != NSNotFound)
		[self takeURLFromBrowser:@"Safari"];
}

#pragma mark -

//--------------------------------------------------------------//
// Drag and drop
//--------------------------------------------------------------//

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	NSPasteboard *pb = [sender draggingPasteboard];
	
	if ([[sender draggingSource] window] != [self window] && [pb availableTypeFromArray:[NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, NSFilenamesPboardType, nil]])
		return NSDragOperationCopy;

	return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	NSPasteboard *pb = [sender draggingPasteboard];
	NSString *type = [pb availableTypeFromArray:[NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, NSFilenamesPboardType, nil]];

	if (type) {
		NSURL *url = nil;
		
		if ([type isEqualToString:NSURLPboardType])
			url = [NSURL URLFromPasteboard:pb];
		else if ([type isEqualToString:NSStringPboardType])
			url = [NSURL URLWithString:[pb stringForType:NSStringPboardType]];
		else if ([type isEqualToString:NSFilenamesPboardType])
			url = [NSURL fileURLWithPath:[[pb propertyListForType:NSFilenamesPboardType] objectAtIndex:0]];
		
		if (url) {
			if ([[url scheme] isEqualToString:@"paparazzi"])
				[self fetchUsingPaparazziURL:url];
			else
				[self fetchUsingString:[url absoluteString]];
			
			return YES;
		}
	}
	
	return NO;
}

#pragma mark -

//--------------------------------------------------------------//
// NSApplication delegation
//--------------------------------------------------------------//

- (BOOL)application:(NSApplication *)app openFile:(NSString *)filename {
	NSURL *fileURL = [NSURL fileURLWithPath:filename];
	[urlField setStringValue:[fileURL absoluteString]];
	[self showWindow:nil];
	[self fetch:nil];
	return YES;
}

- (NSMenu *)captureFromMenu {
	static NSArray *kAppsIKnowHowToGetTheURLFrom;
	
	if (!kAppsIKnowHowToGetTheURLFrom)
		kAppsIKnowHowToGetTheURLFrom = [NSArray arrayWithObjects:@"Safari", @"Camino", nil];
	
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Dock Menu"];
	NSMenuItem *item;
	NSArray *apps = [[NSWorkspace sharedWorkspace] launchedApplications];
	NSEnumerator *appEnum = [apps objectEnumerator];
	NSDictionary *appDict;
	
	while (appDict = [appEnum nextObject]) {
		NSString *name = [appDict objectForKey:@"NSApplicationName"];
		if ([kAppsIKnowHowToGetTheURLFrom containsObject:name]) {
			item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"CaptureURLFrom", nil), name] action:@selector(takeURLFromMyBrowser:) keyEquivalent:@""];
			[menu addItem:item];
		}
	}
	
	return menu;	
}

- (NSMenu *)applicationDockMenu:(NSApplication *)app {
	return [self captureFromMenu];
}

- (BOOL)validateMenuItem:(NSMenuItem*)item {
	SEL action = [item action];
	
	if ((action == @selector(saveDocumentAs:)) && (!currentURL || !bitmap))
		return NO;
	else if (action == @selector(showWindow:)) {
		if ([[self window] isVisible])
			[item setState:NSOnState];
		else
			[item setState:NSOffState];
	} else if ((action == @selector(clearRecentDocuments:)) && ([history count] == 0))
		return NO;
	
	return YES;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication {
	if (![[self window] isVisible])
		[self showWindow:nil];
	
	return YES;
}

#pragma mark -

- (void)cancelOperation:(id)sender {
	if (isLoading)
		[self cancel:sender];
}

#if 0
- (IBAction)print:(id)sender {
	[imageView print:sender];
}
#endif

#pragma mark -

//--------------------------------------------------------------//
// urlField defaults
//--------------------------------------------------------------//

- (void)validateInputSchemeForControl:(NSControl *)control {
	[control setStringValue:[[control stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
	
	NSURL *url = [NSURL URLWithString:[control stringValue]];
	
	if (![[url scheme] length])
		[control setStringValue:[@"http://" stringByAppendingString:[control stringValue]]];	
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
	if (control == urlField)
		[self validateInputSchemeForControl:control];
	else if ((control == maxWidthField || control == maxHeightField) && [control intValue] < 1)
		[control setStringValue:@""];

	return YES;
}

- (IBAction)showPreferences:(id)sender {
	[[PreferencesController controller] showWindow:sender];
}

- (IBAction)sendFeedback:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:paparazzi@derailer.org?subject=Paparazzi!"]];
}

#if 0
- (void)popUpButtonWillPopUp:(NSNotification *)note {
	if ([note object] == takeURLFromPopUp) {
		NSMenu *menu = [self applicationDockMenu:NSApp];
		NSPopUpButton *popup = [note object];
		NSMenu *myMenu = [[note object] menu];
		[popup removeAllItems];
		
		unsigned count = [menu numberOfItems];
		
		unsigned i;
		NSMenuItem *item;
		
		[popup addItemWithTitle:@""];
		
		for (i = 0; i < count; ++i) {
			item = [[menu itemAtIndex:0] retain];
			[menu removeItemAtIndex:0];
			[myMenu addItem:item];
			[item release];
		}
	}
}
#endif

#pragma mark -

- (int)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
	return [history count];
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index {
	return [history objectAtIndex:index];
}

- (NSString *)comboBox:(NSComboBox *)aComboBox completedString:(NSString *)uncompletedString {	
	NSURL *url = [NSURL URLWithString:uncompletedString];
	if ([[url scheme] length] && (![[url resourceSpecifier] length] || [[url resourceSpecifier] isEqualToString:@"/"]))
		return uncompletedString;
		
	NSString *httpString;
	
	if (url && [[url scheme] length])
		httpString = uncompletedString;
	else
		httpString = [@"http://" stringByAppendingString:uncompletedString];
	
	NSEnumerator *e = [history objectEnumerator];
	NSString *obj;
	
	while (obj = [e nextObject]) {
		if ([obj hasPrefix:httpString]) {
			if (url && [[url scheme] length])
				return obj;
			else
				return [obj substringFromIndex:7];
		}
	}
	
	return uncompletedString;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
	if (menu == [captureFromMenuItem submenu]) {
		NSMenu *captureFromMenu = [self captureFromMenu];
		
		while ([menu numberOfItems])
			[menu removeItemAtIndex:0];
		
		NSEnumerator *e = [[captureFromMenu itemArray] objectEnumerator];
		NSMenuItem *item;
		
		while (item = [e nextObject])
			[menu addItem:[item copy]];
	}
}

@end
