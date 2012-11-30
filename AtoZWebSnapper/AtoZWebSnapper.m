//
//  AtoZWebSnapper.m
//  AtoZWebSnapper
//
//  Created by Alex Gray on 9/14/12.
//
//

#import "AtoZWebSnapper.h"


NSString * const kAZWebSnapperUserAgent = @"Paparazzi!/0.3";

NSString * const kAZWebSnapperWebMinWidthKey		= @"WebMinWidth";
NSString * const kAZWebSnapperWebMinHeightKey		= @"WebMinHeight";
NSString * const kAZWebSnapperWebMaxWidthKey		= @"WebMaxWidth";
NSString * const kAZWebSnapperWebMaxHeightKey		= @"WebMaxHeight";
NSString * const kAZWebSnapperSaveFormatKey			= @"SaveFormat";
NSString * const kAZWebSnapperJPEGQualityKey		= @"JPEGQuality";
NSString * const kAZWebSnapperURLHistoryKey			= @"URLHistory";

NSString * const kAZWebSnapperThumbnailScaleKey		= @"ThumbnailScale";
NSString * const kAZWebSnapperSaveImageKey			= @"SaveImage";
NSString * const kAZWebSnapperSaveThumbnailKey		= @"SaveThumbnail";
NSString * const kAZWebSnapperDelayKey				= @"Delay";
NSString * const kAZWebSnapperThumbnailFormatKey	= @"ThumbnailFormat";

// declared extern in PaparazziDefaultsConstants.h
NSString * const kAZWebSnapperFilenameFormatKey			= @"FilenameFormat";
NSString * const kAZWebSnapperThumbnailSuffixKey			= @"ThumbnailSuffix";
NSString * const kAZWebSnapperMaxHistoryKey				= @"MaxHistory";
NSString * const kAZWebSnapperUseGMTKey					= @"UseGMT";


@interface WebPreferences (StuffThatShouldBeInTheHeadersButIsNot)

- (void)setShouldPrintBackgrounds:(BOOL)yesno;

@end

@interface WebView (StuffThatShouldBeInTheHeadersButIsNot)

- (void)setMediaStyle: (NSS*) mediaStyle;

@end


@implementation AtoZWebSnapper
@synthesize currentDelay, currentMax, currentTitle, currentURL;
@synthesize bitmap, pdfData, webView, webWindow;
@synthesize isLoading;

- (void)awakeFromNib {

	self.webHistory = [[AZUSERDEFS objectForKey:kAZWebSnapperURLHistoryKey] mutableCopy];
	self.webWindow = [NSWindow.alloc initWithContentRect:NSMakeRect(-16000.0, -16000.0, 100.0, 100.0) styleMask:NSBorderlessWindowMask backing:NSBackingStoreRetained defer:NO];
	self.webView = [WebView.alloc initWithFrame:NSMakeRect(-16000.0, -16000.0, 100.0, 100.0)];
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


}
- (NSString *)filenameWithFormat: (NSS*) format {
	NSMutableString *str = [NSMutableString stringWithCapacity:128];

	if (format) {
		NSUInteger i = 0, len = format.length;
		NSCalendarDate *now = NSCalendarDate.calendarDate;

		if ([AZUSERDEFS boolForKey:kAZWebSnapperUseGMTKey])
			now.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];

		NSString *key, *rep, *host;

		host = currentURL.host;

		if (!host)
			host = @"localhost";

		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
							  currentTitle,							@"%t",
							  [currentURL absoluteString],			@"%u",
							  [[currentURL path] lastPathComponent],	@"%f",
							  host,									@"%h",
							  [NSString stringWithFormat:@"%lu", [now yearOfCommonEra]],	@"%y",
							  [NSString stringWithFormat:@"%02lu", [now monthOfYear]],		@"%m",
							  [NSString stringWithFormat:@"%02lu", [now dayOfMonth]],		@"%d",
							  [NSString stringWithFormat:@"%02lu", [now hourOfDay]],		@"%H",
							  [NSString stringWithFormat:@"%02lu", [now minuteOfHour]],	@"%M",
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

- (void)saveAsPNG: (NSS*) filename fullSize:(BOOL)saveFullSize thumbnailScale:(float)thumbnailScale thumbnailSuffix: (NSS*) thumbnailSuffix {
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

- (void)saveAsTIFF: (NSS*) filename fullSize:(BOOL)saveFullSize thumbnailScale:(float)thumbnailScale thumbnailSuffix: (NSS*) thumbnailSuffix {
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

- (void)saveAsJPEG: (NSS*) filename usingCompressionFactor:(float)factor fullSize:(BOOL)saveFullSize thumbnailScale:(float)thumbnailScale thumbnailSuffix: (NSS*) thumbnailSuffix {
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

- (void)saveAsPDF: (NSS*) filename {
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

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	if (frame == [sender mainFrame]) {
		WebDataSource *dataSource = [frame dataSource];
		currentURL = [[dataSource request] URL];

		[[self mutableArrayValueForKey:@"webHistory"]addObject:currentURL];
//		[self addURLToHistory:currentURL];
//		[urlField setStringValue:[currentURL absoluteString]];
//		[urlField noteNumberOfItemsChanged];

		currentTitle = [dataSource pageTitle];
//		[[self window] setTitle:[@"Paparazzi!: " stringByAppendingString:currentTitle]];

		// set the size to the natural contents of the page
		NSView *viewport = [[webView.mainFrame frameView] documentView]; // width/height of html page
		NSWindow *viewportWindow = [viewport window];
		NSRect viewportBounds = [viewport bounds];

		[viewportWindow display];
		[viewportWindow setContentSize:viewportBounds.size];
		[viewport setFrame:viewportBounds];

		//[self takeScreenshot];
		[self performSelector:@selector(takeScreenshot) withObject:nil afterDelay:currentDelay]; // allow snapping of Flash sites. XXX make user-definable!

//		[saveButton setEnabled:YES];
//		[pageLoadProgress setHidden:YES];
	}
}



#pragma mark -

- (void)takeScreenshot {
	NSView *viewport = [[webView.mainFrame frameView] documentView]; // width/height of html page
	NSRect viewportBounds = viewport.bounds;

	float cropHeight = currentMax.height ? MIN(currentMax.height, viewportBounds.size.height) : viewportBounds.size.height;

	NSRect cropBounds = NSMakeRect(0.0, viewportBounds.size.height - cropHeight,
								   currentMax.width ? MIN(currentMax.width, viewportBounds.size.width) : viewportBounds.size.width,
								   cropHeight);

	// take the screenshot
	[webView lockFocus];
	bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:cropBounds];
	[webView unlockFocus];

	pdfData = [webView dataWithPDFInsideRect:cropBounds];
	[self willChangeValueForKey:@"snap"];
	self.snap = [NSImage.alloc initWithData:bitmap.TIFFRepresentation];
	[self didChangeValueForKey:@"snap"];
}


@end
