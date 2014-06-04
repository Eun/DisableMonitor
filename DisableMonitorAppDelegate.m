/**
 * DisableMonitor, Disable Monitors on Mac
 *
 * Copyright (C) 2014 Tobias Salzmann
 *
 * DisableMonitor is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 2 of the
 * License, or (at your option) any later version.
 *
 * DisableMonitor is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License for more details. You should have received a copy of the GNU
 * General Public License along with DisableMonitor. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Tobias Salzmann
 */

#import "DisableMonitorAppDelegate.h"
#import <IOKit/graphics/IOGraphicsLib.h>

@implementation DisableMonitorAppDelegate

@synthesize window;

extern AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);
extern io_service_t IOServicePortFromCGDisplayID(CGDirectDisplayID displayID);
extern CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef, CGDirectDisplayID, bool);
extern CGDisplayErr CGSGetDisplayList(CGDisplayCount maxDisplays, CGDirectDisplayID * onlineDspys, CGDisplayCount * dspyCnt);


NSMutableArray *monitorConfigs;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    monitorConfigs = NULL;
}


NSString* screenNameForDisplay(CGDirectDisplayID displayID)
{
    NSString *screenName = nil;
    io_service_t service = IOServicePortFromCGDisplayID(displayID);
    if (service)
    {
        NSDictionary *deviceInfo = (NSDictionary *)IODisplayCreateInfoDictionary(service, kIODisplayOnlyPreferredName);
        NSDictionary *localizedNames = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductName]];
    
        if ([localizedNames count] > 0) {
            screenName = [[localizedNames objectForKey:[[localizedNames allKeys] objectAtIndex:0]] retain];
        }
    
        [deviceInfo release];
    }
    return [screenName autorelease];
}

-(void)ShowError:(NSString*)error
{
    
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(ShowError:) withObject:error waitUntilDone:NO];
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:error];
    [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK",@"ALERT_OK")];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert setMessageText:NSLocalizedString(@"ALERT_ERROR",@"ALERT_ERROR")];
    [alert runModal];
    [alert release];
}

#define ShowError(...) [self ShowError:[NSString stringWithFormat:__VA_ARGS__]];

-(void)MoveAllWindows:(CGDirectDisplayID) display to:(CGDirectDisplayID*)todisplay
{
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    CGRect bounds = CGDisplayBounds(display);
    CGRect dstbounds = CGDisplayBounds(todisplay);
    for (NSDictionary *windowItem in ((NSArray *)windowList))
    {
        NSNumber *windowLayer = (NSNumber*)[windowItem objectForKey:(id)kCGWindowLayer];
        if ([windowLayer intValue] == 0)
        {
            CGRect windowBounds;
            CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)[windowItem objectForKey:(id)kCGWindowBounds], &windowBounds);
            if (CGRectContainsRect(bounds, windowBounds))
            {
                BOOL bSuccess = false;
                NSNumber *windowNumber = (NSNumber*)[windowItem objectForKey:(id)kCGWindowNumber];
                NSNumber *windowOwnerPid = (NSNumber*)[windowItem objectForKey:(id)kCGWindowOwnerPID];
                AXUIElementRef appRef = AXUIElementCreateApplication([windowOwnerPid longValue]);
                if (appRef != nil) {
                    
                    CFArrayRef _windows;
                    if (AXUIElementCopyAttributeValues(appRef, kAXWindowsAttribute, 0, 100, &_windows) == kAXErrorSuccess)
                    {
                        for (int i = 0, len = CFArrayGetCount(_windows); i < len; i++)
                        {
                            AXUIElementRef _windowItem = CFArrayGetValueAtIndex(_windows,i);
                            CGWindowID windowID;
                            if (_AXUIElementGetWindow(_windowItem, &windowID) == kAXErrorSuccess)
                            {
                                if (windowID == windowNumber.longValue)
                                {
                                    NSPoint tmpPos;
                                    tmpPos.x = dstbounds.origin.x;
                                    tmpPos.y = dstbounds.origin.y;
                                    CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&tmpPos));
                                    if(AXUIElementSetAttributeValue(_windowItem,kAXPositionAttribute,(CFTypeRef*)_position) == kAXErrorSuccess){
                                            bSuccess = true;
                                    }
                                }
                            }
                        }
                    }
                    CFRelease(appRef);
                }
                
                if (!bSuccess)
                {
                    NSLog(@"Could not move window %ld of %ld", windowNumber.longValue, windowOwnerPid.longValue);
                }
            }
        }
        
    }
    CFRelease(windowList);
}

-(void)ToggleMonitor:(CGDirectDisplayID) display enabled:(Boolean) enabled
{
    

    CGError err;
    CGDisplayConfigRef config;
    @try {
        
        if (enabled == false)
        {
            CGDirectDisplayID    displays[0x10];
            CGDisplayCount  nDisplays = 0;
            
            CGDisplayErr err = CGSGetDisplayList(0x10, displays, &nDisplays);
            
            if (err == 0 && nDisplays > 0)
            {
                for (int i = 0; i < nDisplays; i++)
                {
                    if (displays[i] == display)
                        continue;
                    if (!CGDisplayIsOnline(displays[i]))
                        continue;
                    if (!CGDisplayIsActive(displays[i]))
                        continue;
                    [self MoveAllWindows:display to:displays[i]];
                    break;
                }
            }
        }

        
        err = CGBeginDisplayConfiguration (&config);
        if (err != 0)
        {
            ShowError(@"Error in CGBeginDisplayConfiguration: %d",err);
            return;
        }
        err = CGSConfigureDisplayEnabled(config, display, enabled);
        if (err != 0)
        {
            ShowError(@"Error in CGSConfigureDisplayEnabled: %d", err);
            return;
        }
        err = CGCompleteDisplayConfiguration(config, kCGConfigurePermanently);
        if (err != 0)
        {
            ShowError(@"Error in CGCompleteDisplayConfiguration: %d", err);
            return;
        }
        
        
    }
    @catch (NSException *exception) {
        
    }
}


-(void)SetMonitorRes:(CGDirectDisplayID) display title:(NSString*) title
{
    CGError err;
    CGDisplayConfigRef config;
    
    
    size_t w;
    size_t h;
    size_t d;
    int r;
    int numConverted = sscanf([title UTF8String], "%lux%lux%lu@%d", &w, &h, &d, &r);
    if (numConverted != 4) {
        numConverted = sscanf([title UTF8String], "%lux%lux%lu", &w, &h, &d);
        if (numConverted != 3) {
            ShowError(@"Error: the mode '%s' couldn't be parsed", [title UTF8String]);
            return;
        } else {
            r=60.0;
        }
    }
    
    @try {
        
        
        CFArrayRef allModes = CGDisplayCopyAllDisplayModes(display, NULL);
        if (allModes == NULL) {
            ShowError(@"Error: failed trying to look up modes for display %u", display);
            return;
        }
        
        CGDisplayModeRef newMode = NULL;
        CGDisplayModeRef possibleMode;
        size_t pw;
        size_t ph;
        size_t pd;
        int pr;
        int looking = 1;
        int i;
        for (i = 0 ; i < CFArrayGetCount(allModes) && looking; i++) {
            possibleMode = (CGDisplayModeRef)CFArrayGetValueAtIndex(allModes, i);
            pw = CGDisplayModeGetWidth(possibleMode);
            ph = CGDisplayModeGetHeight(possibleMode);
            pd = bitDepth(possibleMode);
            pr = (int)CGDisplayModeGetRefreshRate(possibleMode);
            if (pw == w &&
                ph == h &&
                pd == d &&
                pr == r) {
                looking = 0;
                newMode = possibleMode;
            }
        }
        CFRelease(allModes);
        
        if (newMode == NULL) {
            ShowError(@"Error: mode %lux%lux%lu@%d not available on display %u",
                  w, h, d, r, display);
            return;
        }
        
        err = CGBeginDisplayConfiguration (&config);
        if (err != 0)
        {
            ShowError(@"Error in CGBeginDisplayConfiguration: %d\n", err);
            return;
        }
    
        
        err = CGConfigureDisplayWithDisplayMode(config, display, newMode, NULL);
        if (err != 0)
        {
            ShowError(@"Error in CGConfigureDisplayWithDisplayMode: %d\n", err);
            return;
        }
        err = CGCompleteDisplayConfiguration(config, kCGConfigurePermanently);
        if (err != 0)
        {
            ShowError(@"Error in CGCompleteDisplayConfiguration: %d\n", err);
            return;
        }
    }
    @catch (NSException *exception) {
        
    }
}

-(void)MonitorClicked:(id) sender
{
    NSMenuItem * item = (NSMenuItem*)sender;
    CGDirectDisplayID display = (CGDirectDisplayID)[item tag];
    BOOL active = CGDisplayIsActive(display);
    
    if (active == true)
    {
        CGDirectDisplayID    displays[0x10];
        CGDisplayCount  nDisplays = 0;
        CGError err = CGGetActiveDisplayList(0x10, displays, &nDisplays);
        
        if (err == 0 && nDisplays - 1 == 0)
        {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setInformativeText:NSLocalizedString(@"ALERT_LAST_MONITOR",@"ALERT_LAST_MONITOR")];
            [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK",@"ALERT_OK")];
            [alert addButtonWithTitle:NSLocalizedString(@"ALERT_CANCEL",@"ALERT_CANCEL")];
            [alert setAlertStyle:NSCriticalAlertStyle];
            [alert setMessageText:NSLocalizedString(@"ALERT_WARNING",@"ALERT_WARNING")];
            if ([alert runModal] != NSAlertFirstButtonReturn)
            {
                [alert release];
                return;
            }
            [alert release];
        }
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self ToggleMonitor:display enabled:!active];
    });
}

-(void)MonitorResolution:(id) sender
{
    NSMenuItem * item = (NSMenuItem*)sender;
    BOOL active = CGDisplayIsActive([item tag]);
    
    if (active == true)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self SetMonitorRes:[item tag] title:[item title]];
        });
    }
    else
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText:NSLocalizedString(@"ALERT_MONITOR_NOT_ACTIVE",@"ALERT_MONITOR_NOT_ACTIVE")];
        [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK",@"ALERT_OK")];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"ALERT_WARNING",@"ALERT_WARNING")];
        [alert runModal];
        [alert release];
    }
}

-(void)DetectMonitors:(id) sender
{
    CGDirectDisplayID    displays[0x10];
    CGDisplayCount  dspCount = 0;
    CGDisplayErr err = CGSGetDisplayList(0x10, displays, &dspCount);
    
    if (err == 0)
    {
        for(int i = 0; i < dspCount; i++)
        {
            io_service_t service = IOServicePortFromCGDisplayID(displays[i]);
            if (service)
                IOServiceRequestProbe(service, kIOFBUserRequestProbe);
        }
    }
}


size_t bitDepth(CGDisplayModeRef mode) {
    size_t depth = 0;
	CFStringRef pixelEncoding = CGDisplayModeCopyPixelEncoding(mode);
    // my numerical representation for kIO16BitFloatPixels and kIO32bitFloatPixels
    // are made up and possibly non-sensical
    if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(kIO32BitFloatPixels), kCFCompareCaseInsensitive)) {
        depth = 96;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(kIO64BitDirectPixels), kCFCompareCaseInsensitive)) {
        depth = 64;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(kIO16BitFloatPixels), kCFCompareCaseInsensitive)) {
        depth = 48;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(IO32BitDirectPixels), kCFCompareCaseInsensitive)) {
        depth = 32;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(kIO30BitDirectPixels), kCFCompareCaseInsensitive)) {
        depth = 30;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(IO16BitDirectPixels), kCFCompareCaseInsensitive)) {
        depth = 16;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(IO8BitIndexedPixels), kCFCompareCaseInsensitive)) {
        depth = 8;
    }
    CFRelease(pixelEncoding);
    return depth;
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if (menu != statusMenu)
        return;
    
    [statusMenu removeAllItems];
    CGDirectDisplayID    displays[0x10];
    CGDisplayCount  nDisplays = 0;
    
    CGDisplayErr err = CGSGetDisplayList(0x10, displays, &nDisplays);
    
    if (err == 0 && nDisplays > 0)
    {
        NSMutableArray *monitors = [[NSMutableArray alloc] init];
        for (int i = 0; i < nDisplays; i++)
        {
            NSString *name = screenNameForDisplay(displays[i]);
            if (name != nil)
            {
                [monitors addObject: name];
            }
            
            else
            {
                [monitors addObject: [NSString stringWithFormat:@"Display #%d", i + 1]];
            }
        }
        
        for (int i = 0; i < monitors.count; i++)
        {
            int num = 0;
            int index = 1;
            
            if (!CGDisplayIsOnline(displays[i]))
                continue;
            
            for (int j = 0; j < monitors.count; j++)
            {
                if ([monitors[j] caseInsensitiveCompare:monitors[i]] == NSOrderedSame)
                {
                    num++;
                    if (j < i)
                    {
                        index++;
                    }
                }
            }
            
            NSString *name;
            if (num > 1)
                name = [NSString stringWithFormat:@"%@ (%d)", monitors[i], index];
            else
                name = monitors[i];
            
            //NSMenuItem *displayItem = [[NSMenuItem alloc] initWithTitle: name  action:@selector(MonitorClicked:) keyEquivalent:@""];
            NSMenuItem *displayItem = [[NSMenuItem alloc] initWithTitle: name  action:nil keyEquivalent:@""];
            BOOL bActive = CGDisplayIsActive(displays[i]);
            if (bActive)
                [displayItem setState:NSOnState];
            else
                [displayItem setState:NSOffState];
            
            NSMenu *subMenu = [[NSMenu alloc] init];
            NSMenuItem *subItem;

            


            
            CFArrayRef allModes = CGDisplayCopyAllDisplayModes(displays[i], NULL);
            
            if (allModes != NULL)
            {
                CGDisplayModeRef currentMode = CGDisplayCopyDisplayMode(displays[i]);
                
                
                size_t current_w = CGDisplayModeGetWidth(currentMode);
                size_t current_h = CGDisplayModeGetHeight(currentMode);
                size_t current_d = bitDepth(currentMode);
                int current_r = (int)CGDisplayModeGetRefreshRate(currentMode);
                
                
                for (int j = 0, len = CFArrayGetCount(allModes); j < len; j++) {
                    CGDisplayModeRef mode = (CGDisplayModeRef)CFArrayGetValueAtIndex(allModes, j);
                    
                    

                    size_t w = CGDisplayModeGetWidth(mode);
                    size_t h = CGDisplayModeGetHeight(mode);
                    size_t d = bitDepth(mode);
                    int r = (int)CGDisplayModeGetRefreshRate(mode);
                    
                    
                    subItem = [[NSMenuItem alloc] initWithTitle: [NSString stringWithFormat:@"%lux%lux%lu@%d", w, h, d, r] action:@selector(MonitorResolution:)  keyEquivalent:@""];
                    [subItem setTag: displays[i]];
                    NSUInteger newIndex = [[subMenu itemArray] indexOfObject:subItem
                                                 inSortedRange:(NSRange){0, [[subMenu itemArray] count]}
                                                       options:NSBinarySearchingInsertionIndex
                                                     usingComparator:^(id a, id b) {
                                                         return [[b title] compare: [a title] options:NSNumericSearch];
                                                     }];
                    
                    
                    if (current_w == w && current_h == h && current_d == d && current_r == r)
                        [subItem setState:NSOnState];
                    else
                        [subItem setState:NSOffState];
                    [subMenu insertItem:subItem atIndex:newIndex];
                    [subItem release];
                    
                }

                
                CFRelease(allModes);
            }
            

            if (bActive)
            {
                subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_DISABLE",@"MENU_DISABLE") action:@selector(MonitorClicked:)  keyEquivalent:@""];
                [subItem setTag:displays[i]];
                [subMenu insertItem:subItem atIndex:0];
                [subItem release];
            }
            else
            {
                subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_ENABLE",@"MENU_ENABLE") action:@selector(MonitorClicked:)  keyEquivalent:@""];
                [subItem setTag:displays[i]];
                [subMenu insertItem:subItem atIndex:0];
                [subItem release];
            }
            
            [subMenu insertItem:[NSMenuItem separatorItem] atIndex:1];

            /*
            [subMenu insertItem:[NSMenuItem separatorItem] atIndex:[[subMenu itemArray] count]];
            
            subItem = [[NSMenuItem alloc] initWithTitle:@"Custom" action:@selector(MonitorCustomResolution:)  keyEquivalent:@""];
            [subItem setTag:displays[i]];
            [subMenu insertItem:subItem atIndex:[[subMenu itemArray] count]];
            [subItem release];
             */
            
            [subMenu setDelegate:self];
            
            [displayItem setSubmenu:subMenu];
            [statusMenu addItem:displayItem];
            [displayItem release];

        }
        [monitors release];
        
    }
    else
    {
        NSMenuItem *noDisplays = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_NO_MONITOS",@"MENU_NO_MONITOS") action:nil keyEquivalent:@""];
        [statusMenu addItem:noDisplays];
        [noDisplays release];
    }
    
    [statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_DETECT",@"MENU_DETECT") action:@selector(DetectMonitors:) keyEquivalent:@""];
    [statusMenu addItem:menuItem];
    [menuItem release];
}


-(void)awakeFromNib{
    
    
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];

    [statusMenu setDelegate:self];
    [statusItem setMenu:statusMenu];
    [statusItem setImage:[NSImage imageNamed:@"status_icon.png"]];
    [statusItem setHighlightMode:YES];
    
    
}

@end
