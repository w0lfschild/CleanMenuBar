//
//  AppDelegate.m
//  cleanMenu
//
//  Created by Wolfgang Baird on 3/12/17.
//  Copyright © 2017 Kevin M Beaulieu. All rights reserved.
//

#define prefs [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/org.w0lf.cleanMenuBar.plist"]

#import "AppDelegate.h"
#import "PFAboutWindowController.h"

@interface AppDelegate ()
@property PFAboutWindowController *aboutWindowController;
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (weak) IBOutlet NSWindow *window;
@end

NSMutableDictionary *prefsDict;
NSMutableDictionary *menuDict;
NSMutableArray *menuItems;

@implementation AppDelegate

+ (NSImage *)resizedImage:(NSImage *)sourceImage toPixelDimensions:(NSSize)newSize {
    if (! sourceImage.isValid) return nil;
    
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                             initWithBitmapDataPlanes:NULL
                             pixelsWide:newSize.width
                             pixelsHigh:newSize.height
                             bitsPerSample:8
                             samplesPerPixel:4
                             hasAlpha:YES
                             isPlanar:NO
                             colorSpaceName:NSCalibratedRGBColorSpace
                             bytesPerRow:0
                             bitsPerPixel:0];
    rep.size = newSize;
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
    [sourceImage drawInRect:NSMakeRect(0, 0, newSize.width, newSize.height) fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    
    NSImage *newImage = [[NSImage alloc] initWithSize:newSize];
    [newImage addRepresentation:rep];
    return newImage;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    PFMoveToApplicationsFolderIfNecessary();
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:prefs];
    menuItems = [[NSMutableArray alloc] init];
    menuDict = [[NSMutableDictionary alloc] init];
    
    self.aboutWindowController = [[PFAboutWindowController alloc] init];
    [self.aboutWindowController setAppURL:[[NSURL alloc] initWithString:@"https://github.com/w0lfschild/cleanMenuBar"]];
    
    NSStatusBar *sys = [NSStatusBar systemStatusBar];
    _statusItem = [sys statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.highlightMode = true;
    
    NSImage *ico;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"iconFile"])
        ico = [NSImage imageNamed:[[NSUserDefaults standardUserDefaults] objectForKey:@"iconFile"]];
    else
        ico = [NSImage imageNamed:@"icon"];
    ico = [AppDelegate resizedImage:ico toPixelDimensions:NSMakeSize(18, 18)];
    [ico setTemplate:true];
    [_statusItem setImage:ico];
    
    NSMenu *myMenu = [[NSMenu alloc] initWithTitle:@""];
    [myMenu setDelegate:self];
    [_statusItem setMenu:myMenu];
    
    [self generateMenu];
    [self sendMessage:@"org.w0lf.null"];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)menuWillOpen:(NSMenu *)menu{
//    [self generateMenu];
}

- (void)menuNeedsUpdate:(NSMenu *)menu{
//    [self generateMenu];
}

- (IBAction)showAboutWindow:(id)sender {
    [self.aboutWindowController showWindow:nil];
}

- (void)generateMenu {
    prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:prefs];
    
    NSMenu *myMenu = [[NSMenu alloc] initWithTitle:@""];
    [myMenu setDelegate:self];
    
    [[myMenu addItemWithTitle:@"About cleanMenu" action:@selector(showAboutWindow:) keyEquivalent:@""] setTarget:self];
    [[myMenu addItemWithTitle:@"Check for updates..." action:@selector(open) keyEquivalent:@""] setTarget:self];
    [[myMenu addItemWithTitle:@"Plugin installed" action:@selector(open) keyEquivalent:@""] setTarget:self];
    
    NSMenuItem *iconMenu = [[NSMenuItem alloc] init];
    [iconMenu setTitle:@"Statusbar Icon"];
    NSMenu *iconSub = [[NSMenu alloc] init];
    
    NSArray *iconImages = @[@"icon", @"icon1", @"icon2", @"icon3", @"icon4", @"icon5"];
    for (NSString *icnName in iconImages) {
        NSMenuItem *insert = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(changeStatusImage:) keyEquivalent:@""];
        NSImage *ico = [AppDelegate resizedImage:[NSImage imageNamed:icnName] toPixelDimensions:NSMakeSize(18, 18)];
        [ico setTemplate:true];
        [insert setImage:ico];
        [insert setToolTip:icnName];
        [iconSub addItem:insert];
    }
    [iconMenu setSubmenu:iconSub];
    
    NSMenuItem *prefMenu = [[NSMenuItem alloc] init];
    [prefMenu setTitle:@"Options"];
    NSMenu *prefSub = [[NSMenu alloc] init];
    [[prefSub addItemWithTitle:@"Start at Login" action:@selector(open) keyEquivalent:@""] setTarget:self];
    [prefSub addItem:iconMenu];
    [[prefSub addItemWithTitle:@"Report Issue" action:@selector(reportIssue) keyEquivalent:@""] setTarget:self];
    [[prefSub addItemWithTitle:@"Donate" action:@selector(donate) keyEquivalent:@""] setTarget:self];
    [prefMenu setSubmenu:prefSub];
    [myMenu addItem:prefMenu];
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    for (NSString *key in prefsDict) {
        if ([[prefsDict objectForKey:key] boolValue]) {
            NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:(NSString *)key];
            NSBundle *appBundle = [NSBundle bundleWithPath:path];
            NSString *appName = [[appBundle infoDictionary] objectForKey:(id)kCFBundleNameKey];
            if (!appName.length) {
                NSArray *chunks = [key componentsSeparatedByString: @"."];
                appName = [[chunks lastObject] localizedCapitalizedString];
            }
            NSMutableDictionary *newObject = [[NSMutableDictionary alloc] init];
            [newObject setObject:key forKey:@"bundleID"];
            [newObject setObject:appName forKey:@"application"];
            [newObject setObject:[NSNumber numberWithBool:true] forKey:@"hidden"];
            [menuDict setObject:newObject forKey:appName];
        }
    }
    
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    NSArray *myArray=[(__bridge NSArray *)windowList copy];
    for (int i = 0; i < myArray.count; i++) {
        NSDictionary *winInfo = [myArray objectAtIndex:i];
        if ([[winInfo objectForKey:@"kCGWindowLayer"] integerValue] == 25) {
            NSString* appName = [winInfo objectForKey:@"kCGWindowOwnerName"];
            if ([appName isEqualToString:@"SystemUIServer"]) {
                appName = [winInfo objectForKey:@"kCGWindowName"];
                NSRange replaceRange = [appName rangeOfString:@"Apple"];
                if (replaceRange.location != NSNotFound)
                    appName = [appName stringByReplacingCharactersInRange:replaceRange withString:@""];
                replaceRange = [appName rangeOfString:@"Extra"];
                if (replaceRange.location != NSNotFound)
                    appName = [appName stringByReplacingCharactersInRange:replaceRange withString:@""];
            }
            NSString* winName = [winInfo objectForKey:@"kCGWindowName"];
            NSString* bundleID = @"";
            if ([winName isEqualToString:@"Item-0"]) {
                bundleID = [[NSRunningApplication runningApplicationWithProcessIdentifier:[[winInfo objectForKey:@"kCGWindowOwnerPID"] intValue]] bundleIdentifier];
            } else {
                bundleID = appName;
            }
            NSMutableDictionary *newObject = [[NSMutableDictionary alloc] init];
            [newObject setObject:bundleID forKey:@"bundleID"];
            [newObject setObject:appName forKey:@"application"];
            [menuDict setObject:newObject forKey:appName];
        }
    }
    
    NSArray *sortedKeys = [[menuDict allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    for (NSString* key in sortedKeys) {
        NSDictionary *dictforKey = [menuDict objectForKey:key];
        NSString *title = [dictforKey objectForKey:@"application"];
        NSString *toolTip = [dictforKey objectForKey:@"bundleID"];
        NSInteger state = [[dictforKey objectForKey:@"hidden"] boolValue];
        if (title.length) {
            NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(toggleHidden:) keyEquivalent:@""];
            [newItem setToolTip:toolTip];
            [newItem setTarget:self];
            [newItem setState:state];
            [myMenu addItem:newItem];
        }
    }
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    NSString *version =  [NSString stringWithFormat:@"Version %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    [[myMenu addItemWithTitle:version action:@selector(open) keyEquivalent:@""] setTarget:self];
    [[myMenu addItemWithTitle:@"Wolfgang Baird" action:@selector(visitGithub) keyEquivalent:@""] setTarget:self];
    [[myMenu addItemWithTitle:@"Visit website" action:@selector(cleanMBGithub) keyEquivalent:@""] setTarget:self];
    [myMenu addItem:[NSMenuItem separatorItem]];
    [[myMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""] setTarget:NSApp];
    
    [_statusItem setMenu:myMenu];
}

- (void)sendMessage:(NSObject *)message {
    CFNotificationCenterRef center = CFNotificationCenterGetDistributedCenter();
    CFDictionaryKeyCallBacks keyCallbacks = {0, NULL, NULL, CFCopyDescription, CFEqual, NULL};
    CFDictionaryValueCallBacks valueCallbacks  = {0, NULL, NULL, CFCopyDescription, CFEqual};
    CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &keyCallbacks, &valueCallbacks);
    CFDictionaryAddValue(dictionary, CFSTR("bundleID"), (__bridge const void *)(message));
    CFNotificationCenterPostNotification(center, CFSTR("cleanMenu"), NULL, dictionary, true);
    CFRelease(dictionary);
}

- (IBAction)toggleHidden:(id)sender {
    if (!prefsDict)
        prefsDict = [[NSMutableDictionary alloc] init];
    NSString *s = [(NSMenuItem*)sender toolTip];
    [prefsDict setObject:[NSNumber numberWithBool:![sender state]] forKey:s];
    [prefsDict writeToFile:prefs atomically: YES];
    [self sendMessage:s];
    [sender setState:![sender state]];
}

- (IBAction)changeStatusImage:(id)sender {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSImage *ico = [NSImage imageNamed:@"icon"];
    if ([(NSMenuItem*)sender image] != nil) {
        ico = [(NSMenuItem*)sender image];
        [def setObject:[sender toolTip] forKey:@"iconFile"];
    }
    [_statusItem setImage:ico];
}

- (void)reportIssue {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild/DarkBoot/issues/new"]];
}

- (void)donate {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://goo.gl/DSyEFR"]];
}

- (void)visitGithub {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild"]];
}

- (void)cleanMBGithub {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild/cleanMenuBar"]];
}

@end
