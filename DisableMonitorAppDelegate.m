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
#import <IOKit/i2c/IOI2CInterface.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import "DisplayData.h"
#import "ResolutionDataSource.h"
#import "ResolutionDataItem.h"
#import "OnlyIntegerValueFormatter.h"
#import "DisplayIDAndNameCondition.h"
#import "MonitorDataSource.h"
#import "NSImage+NegativeImage.h"
#include <stdlib.h>


@implementation DisableMonitorAppDelegate

@synthesize pref_window;
@synthesize pref_lblHeader;
@synthesize pref_btnClose;
@synthesize pref_lstResolutions;
@synthesize pref_chkDisableMonitor;
@synthesize pref_chkEnableMonitor;
@synthesize pref_lstDisableMonitors;
@synthesize pref_lstEnableMonitors;
@synthesize pref_tabView;
@synthesize about_window;
@synthesize about_btnUpdate;
@synthesize about_btnWeb;
@synthesize about_lblAppName;
@synthesize about_lblVersion;

@synthesize window_display;
@synthesize updater;

#define UPDATE_INTERVAL 60*60*24*7


CFStringRef const kDisplayBrightness = CFSTR(kIODisplayBrightnessKey);

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
    
}


-(void)awakeFromNib{
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusMenu setDelegate:self];
    [statusItem setMenu:statusMenu];
    NSImage *statusImage = [NSImage imageResize:[[NSImage imageNamed:@"icon.icns"] copy] newSize:NSMakeSize(20, 20)];
    
    
    if ([self isInDarkMode])
    {
        NSImage *normalImage = statusImage;
        statusImage = [normalImage negativeImage];
        [normalImage release];
    }
    
    
    [self setupAboutWindow];
    [self setupPreferencesWindow];
    
    [statusItem setImage:statusImage];
    [statusItem setHighlightMode:YES];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeChanged:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
    CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallBack, NULL);
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    unsigned long now = [[NSDate date] timeIntervalSince1970];
    unsigned long nextCheck = [userDefaults integerForKey:@"lastUpdateCheck"] + UPDATE_INTERVAL;
    if (nextCheck < now)
    {
        [updater checkForUpdatesInBackground];
        [userDefaults setInteger:now forKey:@"lastUpdateCheck"];
        [userDefaults synchronize];
    }
}


#pragma mark Helper functions
- (BOOL)isInDarkMode
{
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] persistentDomainForName:NSGlobalDomain];
    id style = [dict objectForKey:@"AppleInterfaceStyle"];
    return ( style && [style isKindOfClass:[NSString class]] && NSOrderedSame == [style caseInsensitiveCompare:@"dark"] );
}

-(void)darkModeChanged:(NSNotification *)notif
{
    NSImage *statusImage = [NSImage imageResize:[[NSImage imageNamed:@"icon.icns"] copy] newSize:NSMakeSize(20, 20)];
    if ([self isInDarkMode])
    {
        NSImage *normalImage = statusImage;
        statusImage = [normalImage negativeImage];
        [normalImage release];
    }
    [statusItem setImage:statusImage];
}

+(void)ShowError:(NSString*)error
{
    
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(ShowError:) withObject:error waitUntilDone:NO];
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:error];
    [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert setMessageText:NSLocalizedString(@"ALERT_ERROR", NULL)];
    [alert runModal];
    [alert release];
}

#define ShowError(...) [DisableMonitorAppDelegate ShowError:[NSString stringWithFormat:__VA_ARGS__]];

/**
 *  move all windows from one display to another
 *
 *  @param display   source display
 *  @param todisplay destination display
 */
+(void)moveAllWindows:(CGDirectDisplayID) display to:(CGDirectDisplayID*)todisplay
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
            if (CGRectContainsPoint(bounds, windowBounds.origin))
            {
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
                                    if(AXUIElementSetAttributeValue(_windowItem,kAXPositionAttribute,(CFTypeRef*)_position) != kAXErrorSuccess){
                                        NSString* windowName = (NSString*)[windowItem objectForKey:(id)kCGWindowName];
                                        NSLog(@"Could not move window %ld (%@) of %ld", windowNumber.longValue, windowName, windowOwnerPid.longValue);
                                    }
                                }
                            }
                        }
                    }
                    CFRelease(appRef);
                }
            }
        }
        
    }
    CFRelease(windowList);
}

/**
 *  get the currentstate of a display
 *
 *  @param displayID display to check
 *
 *  @return YES if the display is enabled
 */
+(bool)isDisplayEnabled:(CGDirectDisplayID)displayID
{
    if (!CGDisplayIsOnline(displayID))
        return NO;
     // if the display is not active, it could be in a mirrorset
    if (CGDisplayIsActive(displayID) == NO)
    {
        if (CGDisplayIsInMirrorSet(displayID))
            return YES;
        else
            return NO;
    }
    return YES;
}
/**
 *  show warning if user is going to disable last monitor
 *
 *  @return true if the user choses to abort
 */
+(bool) showErrorWarningIfLastMonitor:(CGDirectDisplayID)displayID
{
    if ([DisableMonitorAppDelegate isDisplayEnabled:displayID] && displayID == CGDisplayPrimaryDisplay(displayID))
    {
        CGDirectDisplayID    displays[0x10];
        CGDisplayCount  nDisplays = 0;
        CGError err = CGGetActiveDisplayList(0x10, displays, &nDisplays);
        
        if (err == 0 && nDisplays - 1 == 0)
        {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setInformativeText:NSLocalizedString(@"ALERT_LAST_MONITOR", NULL)];
            [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
            [alert addButtonWithTitle:NSLocalizedString(@"ALERT_CANCEL", NULL)];
            [alert setAlertStyle:NSCriticalAlertStyle];
            [alert setMessageText:NSLocalizedString(@"ALERT_WARNING", NULL)];
            if ([alert runModal] != NSAlertFirstButtonReturn)
            {
                [alert release];
                return true;
            }
            [alert release];
        }
    }
    return false;
}

/**
 *  toggle a monitor state from disabled to enabled or reverse.
 *
 *  @param displayID the display id of the monitor
 *  @param enabled   should it be enabled or disabled?
 */
+(void)toggleMonitor:(CGDirectDisplayID)displayID enabled:(Boolean) enabled
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
                    if (displays[i] == displayID)
                        continue;
                    if (!CGDisplayIsOnline(displays[i]))
                        continue;
                    if (!CGDisplayIsActive(displays[i]))
                        continue;
                    @try {
                        [self moveAllWindows:displayID to:displays[i]];
                    }
                    @catch (NSException *e)
                    {
                        NSLog(@"Problems in moving windows");
                    }
                    break;
                }
            }
        }
        
        usleep(1000*1000); // sleep 1000 ms
        
        err = CGBeginDisplayConfiguration (&config);
        if (err != 0)
        {
            ShowError(@"Error in CGBeginDisplayConfiguration: %d",err);
            return;
        }
        
        bool mirror = CGDisplayIsInMirrorSet(displayID);
        if (enabled == false && mirror)
        {
            CGConfigureDisplayMirrorOfDisplay(config, displayID, kCGNullDirectDisplay);
        }
        
        err = CGSConfigureDisplayEnabled(config, displayID, enabled);
        if (err != 0)
        {
            ShowError(@"Error in CGSConfigureDisplayEnabled: %d", err);
            return;
        }
        
        if (!mirror)
        {
            CGConfigureDisplayFadeEffect (config, 0, 0, 0, 0, 0);
            
            io_registry_entry_t entry = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler");
            if (entry)
            {
                IORegistryEntrySetCFProperty(entry, CFSTR("IORequestIdle"), kCFBooleanTrue);
                usleep(100*1000); // sleep 100 ms
                IORegistryEntrySetCFProperty(entry, CFSTR("IORequestIdle"), kCFBooleanFalse);
                IOObjectRelease(entry);
            }
        }
        
        err = CGCompleteDisplayConfiguration(config, kCGConfigurePermanently);
        if (err != 0)
        {
            ShowError(@"Error in CGCompleteDisplayConfiguration: %d", err);
        }
        
    }
    @catch (NSException *exception) {
        NSLog(@"Exception:" );
        NSLog(@"Name: %@", exception.name);
        NSLog(@"Reason: %@", exception.reason );
    }
}


-(void)setMonitorRes:(CGDirectDisplayID) display mode:(CGSDisplayMode) mode
{
    CGError err;
    CGDisplayConfigRef config;
    err = CGBeginDisplayConfiguration (&config);
    if (err != 0)
    {
        ShowError(@"Error in CGBeginDisplayConfiguration: %d\n", err);
        return;
    }
    
    
    err = CGSConfigureDisplayMode(config, display, mode.modeNumber);
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

#pragma mark Menu actions
/**
 *  user clicked on enable / disable monitor
 *
 *  @param sender menuItem
 */
-(void)monitorClicked:(id) sender
{
    NSMenuItem * item = (NSMenuItem*)sender;
    CGDirectDisplayID displayId = [(DisplayData*)[item representedObject] display];
    if ([DisableMonitorAppDelegate showErrorWarningIfLastMonitor:displayId])
        return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [DisableMonitorAppDelegate toggleMonitor:displayId enabled:![DisableMonitorAppDelegate isDisplayEnabled:displayId]];
    });
}

/**
 *  user clicked on a resolution that should be changed now
 *
 *  @param sender menuItem
 */
-(void)monitorResolutionClicked:(id) sender
{
    NSMenuItem *item = (NSMenuItem*)sender;
    DisplayData *data = [item representedObject];
    if (CGDisplayIsActive([data display]))
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self setMonitorRes:[data display] mode:[data mode]];
        });
    }
    else
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText:NSLocalizedString(@"ALERT_MONITOR_NOT_ACTIVE", NULL)];
        [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"ALERT_WARNING", NULL)];
        [alert runModal];
        [alert release];
    }
}

/**
 *  user clicked on detect monitors
 *
 *  @param sender menuItem
 */
-(void)detectMonitorsClicked:(id) sender
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
            {
                IOServiceRequestProbe(service, kIOFBUserRequestProbe);
            }
  
        }
    }
}

/**
 *  user clicked on turn off monitors
 *
 *  @param sender menuItem
 */
-(void)turnOffMonitorsClicked:(id) sender
{
    io_registry_entry_t entry = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler");
    if (entry)
    {
        IORegistryEntrySetCFProperty(entry, CFSTR("IORequestIdle"), kCFBooleanTrue);
        IOObjectRelease(entry);
    }
    else
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText: NSLocalizedString(@"ERROR_TURNOFF", NULL)];
        [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"ALERT_ERROR",NULL)];
        [alert runModal];
        [alert release];
    }
}

/**
 *  user clicked on start screensaver
 *
 *  @param sender menuItem
 */
-(void)startScreenSaverClicked:(id) sender
{
    [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/Frameworks/ScreenSaver.framework/Versions/A/Resources/ScreenSaverEngine.app"];
}

/**
 *  user clicked on quit
 *
 *  @param sender menuItem
 */
-(void)quitClicked:(id) sender
{
    [NSApp terminate: nil];
}


/**
 *  user clicked on manage
 *
 *  @param sender menuItem
 */
-(void)manageClicked:(id) sender
{
    NSMenuItem * item = (NSMenuItem*)sender;
    
    CGDirectDisplayID display = [(DisplayData*)[item representedObject] display];
    if (CGDisplayIsOnline(display))
    {
        [self showPreferencesWindow:display name:[[item parentItem] title]];
    }
    
}

# pragma mark NSMenuDelegates

/**
 *  NSMenuDelegate: menuNeedsUpdate
 *
 *  @param menu menu
 */
- (void)menuNeedsUpdate:(NSMenu *)menu
{
    [self releaseMenu:menu];
    
    NSMutableArray *dict = [MonitorDataSource GetSortedDisplays];
    if (dict == nil)
    {
        
        NSMenuItem *noDisplays = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_NO_MONITOS",NULL) action:nil keyEquivalent:@""];
        [statusMenu addItem:noDisplays];
        [noDisplays release];
    }
    else
    {
        for (DisplayIDAndName* idAndName in dict)
        {
            CGDirectDisplayID displayId = [idAndName id];
            NSMenuItem *displayItem = [[NSMenuItem alloc] initWithTitle: [idAndName name]  action:nil keyEquivalent:@""];
            BOOL bActive = CGDisplayIsActive(displayId);
            BOOL bMirror = NO;
            if (bActive == NO)
            {
                bMirror = CGDisplayIsInMirrorSet(displayId);
                if (bMirror)
                {
                    bActive = YES;
                }
            }
            
            if (bActive)
                [displayItem setState:NSOnState];
            else
                [displayItem setState:NSOffState];
            
            
            NSMenu *subMenu = [[NSMenu alloc] init];
            
            NSMenuItem *subItem;
            
            ResolutionDataSource *dataSource = [[ResolutionDataSource alloc] initWithDisplay:displayId];
            int numberOfDisplayModes = [dataSource outlineView:nil numberOfChildrenOfItem:nil];
            if (bActive && numberOfDisplayModes > 0 && bMirror == NO)
            {
                [subMenu addItem:[[NSMenuItem separatorItem] copy]];
                int currentDisplayModeNumber;
                CGSGetCurrentDisplayMode(displayId, &currentDisplayModeNumber);
                NSTableColumn *tableColumn = [[NSTableColumn alloc] init];
                [tableColumn setIdentifier:@"Name"];
                for (int j = 0; j < numberOfDisplayModes; j++)
                {
                    ResolutionDataItem *dataItem = [dataSource outlineView:nil child:j ofItem:nil];
                    if ([dataItem visible])
                    {
                        subItem = [[NSMenuItem alloc] initWithTitle: @"" action:@selector(monitorResolutionClicked:)  keyEquivalent:@""];
                        
                        DisplayData *data = [[DisplayData alloc] init];
                        [data setMode:[dataItem mode]];
                        [data setDisplay:displayId];
                        [subItem setRepresentedObject: data];
                        if (currentDisplayModeNumber == dataItem.mode.modeNumber)
                            [subItem setState:NSOnState];
                        else
                            [subItem setState:NSOffState];
                        [subItem setAttributedTitle:[dataSource outlineView:nil objectValueForTableColumn:tableColumn byItem:dataItem]];
                        [subMenu addItem:subItem];
                    }
                }
                [tableColumn release];
            }
            
            [dataSource release];
            
            if (bActive)
            {
                subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_DISABLE",NULL) action:@selector(monitorClicked:)  keyEquivalent:@""];
                DisplayData *data = [[DisplayData alloc] init];
                [data setDisplay:displayId];
                [subItem setRepresentedObject: data];
                [subMenu insertItem:subItem atIndex:0];
            }
            else
            {
                subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_ENABLE",NULL) action:@selector(monitorClicked:)  keyEquivalent:@""];
                DisplayData *data = [[DisplayData alloc] init];
                [data setDisplay:displayId];
                [subItem setRepresentedObject: data];
                [subMenu insertItem:subItem atIndex:0];
            }
            
            
            
                [subMenu insertItem:[[NSMenuItem separatorItem] copy] atIndex:[[subMenu itemArray] count]];
                
                subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_MANAGE",NULL)  action:@selector(manageClicked:)  keyEquivalent:@""];
                DisplayData *data = [[DisplayData alloc] init];
                [data setDisplay:displayId];
                [subItem setRepresentedObject: data];
                [subItem setOffStateImage:[NSImage imageNamed: NSImageNameSmartBadgeTemplate]];
                [subMenu insertItem:subItem atIndex:[[subMenu itemArray] count]];
            
            [displayItem setSubmenu:subMenu];
            [statusMenu addItem:displayItem];
            [idAndName release];
            

            //subItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%u", displayId] action:nil  keyEquivalent:@""];
            //[subMenu insertItem:subItem atIndex:0];

        }
        [dict release];
    }
    
    
    
    [statusMenu addItem:[[NSMenuItem separatorItem] copy]];
    

    
    menuItemLock = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_TURNOFF",NULL) action:@selector(turnOffMonitorsClicked:) keyEquivalent:@""];
    [menuItemLock setOffStateImage:[NSImage imageNamed: NSImageNameLockLockedTemplate]];
    [statusMenu addItem:menuItemLock];
    
    menuItemScreenSaver = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_SCREENSAVER",NULL) action:@selector(startScreenSaverClicked:) keyEquivalent:@""];
    [menuItemScreenSaver setOffStateImage:[NSImage imageNamed: NSImageNameLockLockedTemplate]];
    //[menuItemScreenSaver setHidden:YES];
    [statusMenu addItem:menuItemScreenSaver];
    
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_DETECT",NULL) action:@selector(detectMonitorsClicked:) keyEquivalent:@""];
    [menuItem setOffStateImage:[NSImage imageNamed: NSImageNameRefreshTemplate]];
    [statusMenu addItem:menuItem];
    
    [statusMenu addItem:[[NSMenuItem separatorItem] copy]];
    
    menuItem = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_ABOUT",NULL) action:@selector(showAboutWindow) keyEquivalent:@""];
    [statusMenu addItem:menuItem];
    
    menuItemQuit = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_QUIT",NULL) action:@selector(quitClicked:) keyEquivalent:@""];
    //[menuItemQuit setHidden:YES];
    [statusMenu addItem:menuItemQuit];

    /*NSTimer *t = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(updateMenu:) userInfo:statusMenu repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:t forMode:NSEventTrackingRunLoopMode];
     */
}

#pragma mark Menu Helpers

/**
 *  triggers every 100ms to detect if the user has pressed the opt key.
 *  If so enable the alternative menu items
 *  @param timer timer
 */
- (void)updateMenu:(NSTimer *)timer {
    
    CGEventRef event = CGEventCreate (NULL);
    CGEventFlags flags = CGEventGetFlags (event);
    BOOL optionKeyIsPressed = (flags & kCGEventFlagMaskAlternate) == kCGEventFlagMaskAlternate;
    CFRelease(event);
    
    [menuItemLock setHidden:optionKeyIsPressed];
    [menuItemScreenSaver setHidden:!optionKeyIsPressed];
    [menuItemQuit setHidden:!optionKeyIsPressed];
}

/**
 *  relase the current menu structure to build a new one.
 *
 *  @param menu menu that should be released.
 */
- (void) releaseMenu:(NSMenu*)menu
{
    NSArray *items = [menu itemArray];
    
    if (items != NULL)
    {
        for (int i = [items count] - 1; i >= 0; --i)
        {
            NSMenuItem *item = [items objectAtIndex:i];
            if ([item submenu] != NULL)
            {
                [self releaseMenu:[item submenu]];
                [[item submenu] release];
            }
            
            id representedObject = [item representedObject];
            if (representedObject != NULL)
            {
                [representedObject release];
            }
            [item release];
           
        }
        [menu removeAllItems];
    }
}


#pragma mark rulset

/**
 *  check if there is a condition that matches a rule
 *
 *  @param displayThatChanged display that changed
 *  @param isAdded            was it added or removed?
 *  @param display            displayID of the display which rules should be checked
 *  @param dict               dict to the settings of the display
 *  @param listToUse          which list should be used (in settings)
 *
 *  @return if there is a rule that matches
 */
bool matchesConditions(CGDirectDisplayID displayThatChanged, bool isAdded, CGDirectDisplayID display, NSMutableDictionary *dict, NSString *listToUse)
{
    
    NSMutableArray *items = [dict objectForKey:listToUse];
    for (int i = [items count] - 1; i>= 0; --i)
    {
        DisplayIDAndNameCondition *store_item =[NSKeyedUnarchiver unarchiveObjectWithData:[items objectAtIndex:i]];
        
        bool displayOnline;
        if ([store_item id] == displayThatChanged)
            displayOnline  = isAdded;
        else
            displayOnline = CGDisplayIsOnline([store_item id]) && CGDisplayIsActive([store_item id]);
        if (displayOnline && [store_item disabled])
            return false;
        if (!displayOnline && [store_item enabled])
            return false;
        
    }
    
    return true;
}

/**
 *  trigger the rule that should be run if the specified display gets attached or removed.
 *
 *  @param displayThatChanged displayID of the display that gets removed
 *  @param isAdded            was it added or removed?
 */
void triggerRules(CGDirectDisplayID displayThatChanged, bool isAdded)
{
    
    CGDirectDisplayID    displays[0x10];
    CGDisplayCount  nDisplays = 0;
    
    CGDisplayErr err = CGSGetDisplayList(0x10, displays, &nDisplays);
    
    if (err == 0 && nDisplays > 0)
    {
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        for (int i = 0; i < nDisplays; i++)
        {
            if (CGDisplayIsOnline(displays[i]))
            {
                NSMutableDictionary *dict = [ResolutionDataSource getDictForDisplay:userDefaults display:displays[i]];
                if ([dict count] == 0)
                {
                    continue;
                }
                if ([[dict objectForKey:@"enable_rules"] boolValue] == true)
                {
                    if (matchesConditions(displayThatChanged, isAdded, displays[i], dict, @"enable_ruleset"))
                    {
                        if (CGDisplayIsActive(displays[i]))
                            continue;
                        NSLog(@"ENABLE %u", displays[i]);
                        if (![DisableMonitorAppDelegate showErrorWarningIfLastMonitor:displays[i]])
                        {
                            CGDirectDisplayID displayID = displays[i];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                [DisableMonitorAppDelegate toggleMonitor:displayID enabled:YES];
                            });
                        }
                        continue;
                    }
                }
                if ([[dict objectForKey:@"disable_rules"] boolValue] == true)
                {
                    if (matchesConditions(displayThatChanged, isAdded, displays[i], dict, @"disable_ruleset"))
                    {
                         if (!CGDisplayIsActive(displays[i]))
                            continue;
                        NSLog(@"DISABLE %u", displays[i]);
                        if (![DisableMonitorAppDelegate showErrorWarningIfLastMonitor:displays[i]])
                        {
                            CGDirectDisplayID displayID = displays[i];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                [DisableMonitorAppDelegate toggleMonitor:displayID enabled:NO];
                            });
                        }
                        
                        continue;
                    }
                }
            }
        }
    }
}

/**
 *  called when a display gets attached or removed
 *
 *  @param display  displayID of the display
 *  @param flags    flags
 *  @param userInfo userInfo
 */
void displayReconfigurationCallBack(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo)
{
    if ((flags & kCGDisplayAddFlag) == kCGDisplayAddFlag) {
        triggerRules(display, true);
    }
    else if ((flags & kCGDisplayRemoveFlag) == kCGDisplayRemoveFlag) {
        triggerRules(display, false);
    }
}


#pragma mark General Window stuff
/**
 *  NSWindowDelegate: will be called when about or preferences window will be closed
 *
 *  @param notification notification
 */
- (void)windowWillClose:(NSNotification *)notification {
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    TransformProcessType(&psn, 2 /*kProcessTransformToBackgroundApplication*/);
    if ([notification object] == pref_window)
    {
        [[pref_lstResolutions dataSource] release];
        [[pref_lstEnableMonitors dataSource] release];
        [[pref_lstDisableMonitors dataSource] release];
    }
}

#pragma mark About Window
/**
 *  setup the about window
 */
-(void)setupAboutWindow
{
    [about_window setTitle: NSLocalizedString(@"MENU_ABOUT", NULL)];
    [about_window setLevel:NSFloatingWindowLevel];
    [about_window setDelegate:self];
    [about_btnUpdate setTitle:NSLocalizedString(@"CHECK_FOR_UPDATES", NULL)];
    [about_btnUpdate sizeToFit];
    [about_btnUpdate setFrameOrigin: NSMakePoint(
                                                 
                                                 [about_window frame].size.width -
                                                 [about_btnUpdate frame].size.width
                                                 - 13
                                                 , [about_btnUpdate frame].origin.y)];
    
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    [about_lblVersion setStringValue:[infoDict objectForKey:@"CFBundleVersion"]];
    [about_lblAppName setStringValue:[infoDict objectForKey:@"CFBundleExecutable"]];
}

/**
 *  show the about window
 */
-(void)showAboutWindow
{
    [pref_window close];
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    [about_window makeKeyAndOrderFront:self];
    [about_window makeFirstResponder: nil];
}

/**
 *  open the project home page
 *
 *  @param sender sender object
 */
-(IBAction)openHomePage:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/Eun/DisableMonitor"]];
}

/**
 *  button action that checkes for updates
 *
 *  @param sender sender object
 */
-(IBAction)checkForUpdates:(id)sender
{
    [updater checkForUpdates:sender];
}



#pragma mark Preferences Window
/**
 *  initializes the preferences window
 */
-(void)setupPreferencesWindow
{
    [pref_window setLevel:NSFloatingWindowLevel];
    [pref_window setDelegate:self];
    [[pref_tabView tabViewItemAtIndex:0] setLabel:NSLocalizedString(@"PREF_TAB_RESOLUTIONS", NULL)];
    [[pref_tabView tabViewItemAtIndex:1] setLabel:NSLocalizedString(@"PREF_TAB_RULES", NULL)];
    // Rules are beta for now
    {
        NSView *view = [[pref_tabView tabViewItemAtIndex:1] view];
        [view removeFromSuperview];
        [[[pref_tabView tabViewItemAtIndex:0] view] addSubview:view];
        [view setHidden:YES];
        [pref_tabView removeTabViewItem:[pref_tabView tabViewItemAtIndex:1]];
    }
    [pref_btnClose setTitle:NSLocalizedString(@"PREF_CLOSE", NULL)];
    [pref_btnClose sizeToFit];
    [pref_btnClose setFrameOrigin: NSMakePoint(
                                               
                                               [pref_window frame].size.width -
                                               [pref_btnClose frame].size.width
                                               - 13
                                               , [pref_btnClose frame].origin.y)];
    
    [pref_lblHeader setStringValue:NSLocalizedString(@"PREF_LABEL", NULL)];
    [pref_chkEnableMonitor setTitle:NSLocalizedString(@"PREF_ENABLE_MONITOR", NULL)];
    [pref_chkDisableMonitor setTitle:NSLocalizedString(@"PREF_DISABLE_MONITOR", NULL)];
}

/**
 *  shows the preferences window for a specific display
 *
 *  @param displayID the displayID to be used
 *  @param name      the name of the display
 */
-(void)showPreferencesWindow:(CGDirectDisplayID)displayID name:(NSString*)name
{
    [about_window close];
    window_display = displayID;
    [pref_window setTitle: name];
    // Load Settings
    [pref_lstResolutions setDataSource:[[ResolutionDataSource alloc] initWithDisplay:displayID]];
    //[pref_lstResolutions setDelegate:self];
    [pref_lstEnableMonitors setDataSource:[[MonitorDataSource alloc] initWithDisplay:displayID useEnableList:true]];
    [pref_lstDisableMonitors setDataSource:[[MonitorDataSource alloc] initWithDisplay:displayID useEnableList:false]];
    
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [ResolutionDataSource getDictForDisplay:userDefaults display:displayID];
    if ([[dict objectForKey:@"enable_rules"] boolValue] == true)
        [pref_chkEnableMonitor setState:NSOnState];
    else
        [pref_chkEnableMonitor setState:NSOffState];
    
    if ([[dict objectForKey:@"disable_rules"] boolValue] == true)
        [pref_chkDisableMonitor setState:NSOnState];
    else
        [pref_chkDisableMonitor setState:NSOffState];
    
    [self prefEnableDisableBoxChanged:nil];
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    [pref_window makeKeyAndOrderFront:self];
    [pref_window makeFirstResponder: nil];
}

/**
 *  will be executed if the user enables / disables the ruleset
 *
 *  @param sender checkbox
 */
- (IBAction)prefEnableDisableBoxChanged:(id)sender
{
    [pref_lstEnableMonitors setEnabled: ([pref_chkEnableMonitor state] == NSOnState)];
    [pref_lstDisableMonitors setEnabled: ([pref_chkDisableMonitor state] == NSOnState)];
    
    if (sender != nil)
    {
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *dict = [ResolutionDataSource getDictForDisplay:userDefaults display:window_display];
        [dict setObject:[NSNumber numberWithBool:([pref_chkEnableMonitor state] == NSOnState)] forKey:@"enable_rules"];
        [dict setObject:[NSNumber numberWithBool:([pref_chkDisableMonitor state] == NSOnState)] forKey:@"disable_rules"];
        [userDefaults setObject:dict forKey:[NSString stringWithFormat:@"%u", window_display]];
        [userDefaults synchronize];
    }
    
}

/**
 *  closes the preferences window
 *
 *  @param sender sender
 */
- (IBAction)closePrefWindow:(id)sender
{
    [pref_window close];
}

@end
