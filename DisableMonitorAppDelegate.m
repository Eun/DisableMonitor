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
#import "DisplayData.h"
#import "ResolutionDataSource.h"
#import "ResolutionDataItem.h"
#import "CustomResolution.h"
#import "OnlyIntegerValueFormatter.h"
#include <stdlib.h>

@implementation DisableMonitorAppDelegate

@synthesize window_label;
@synthesize window_list;
@synthesize window;
@synthesize window_display;
@synthesize window_btndel;
@synthesize window_btnclose;
@synthesize window_panel;

@synthesize panel_lblwidth;
@synthesize panel_lblheight;
@synthesize panel_txtwidth;
@synthesize panel_txtheight;
@synthesize panel_lblratio;
@synthesize panel_btnok;
@synthesize panel_btncancel;



- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

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
    [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert setMessageText:NSLocalizedString(@"ALERT_ERROR", NULL)];
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
                    @try {
                        [self MoveAllWindows:display to:displays[i]];
                    }
                    @catch (NSException *e)
                    {
                        NSLog(@"Problems in moving windows");
                    }
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


-(void)SetMonitorRes:(CGDirectDisplayID) display mode:(CGSDisplayMode) mode
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

-(void)MonitorClicked:(id) sender
{
    NSMenuItem * item = (NSMenuItem*)sender;
    CGDirectDisplayID display = [(DisplayData*)[item representedObject] display];
    BOOL active = CGDisplayIsActive(display);
    
    if (active == true)
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
    DisplayData *data = [item representedObject];
    BOOL active = CGDisplayIsActive([data display]);
    
    if (active == true)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self SetMonitorRes:[data display] mode:[data mode]];
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
/*
void* IOFBConnectToRef( io_connect_t connect )
{
    return((void* ) CFDictionaryGetValue( gConnectRefDict, (void *) (uintptr_t) connect ));
}


extern void IOFBCreateOverrides(void* connectRef);*/
-(void)DetectMonitors:(id) sender
{
    
    /*
    io_connect_t			masterPort;
    IOMasterPort(MACH_PORT_NULL, &masterPort);
    void* connectRef = IOFBConnectToRef( masterPort );
    IOFBCreateOverrides(connectRef);*/
    
   // IOFramebufferServerOpen(MACH_PORT_NULL);
    
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


-(void)ManageResolution:(id) sender
{
    NSMenuItem * item = (NSMenuItem*)sender;
    
    CGDirectDisplayID display = [(DisplayData*)[item representedObject] display];
    
    ProcessSerialNumber psn = { 0, kCurrentProcess };
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    
    
    CGDirectDisplayID    displays[0x10];
    CGDisplayCount  nDisplays = 0;
    
    CGDisplayErr err = CGSGetDisplayList(0x10, displays, &nDisplays);
    
    if (err == 0 && nDisplays > 0)
    {
        NSString *displayName = NULL;
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
                if ([[monitors objectAtIndex:j] caseInsensitiveCompare:[monitors objectAtIndex:i]] == NSOrderedSame)
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
                name = [NSString stringWithFormat:@"%@ (%d)", [monitors objectAtIndex:i], index];
            else
                name = [monitors objectAtIndex:i];
            
            
            if (displays[i] == display)
            {
                displayName = name;
                break;
            }
            
        }
        
        assert(displayName);
        
        window_display = display;
        
        customResolution = [[CustomResolution alloc] initWithDisplayID:window_display];
        [window setTitle:displayName];
        [window setDelegate:self];
        [window makeKeyAndOrderFront:self];
        [window setLevel:NSFloatingWindowLevel];
        [window_list setDataSource:[[ResolutionDataSource alloc] initWithDisplay:display]];
        [window_list setDelegate:self];
        [window_label setStringValue:NSLocalizedString(@"CUSTOM_LABEL", NULL)];
        [window_btnclose setTitle:NSLocalizedString(@"ALERT_CANCEL", NULL)];
        [window_btnclose sizeToFit];
        [window makeFirstResponder: nil];
        [monitors release];
    }
    
}

- (void)windowWillClose:(NSNotification *)notification {
    ProcessSerialNumber psn = { 0, kCurrentProcess };
	TransformProcessType(&psn, kProcessTransformToBackgroundApplication);
    [customResolution release];
}

- (IBAction)AddCustomResoultion:(id)sender
{
    OnlyIntegerValueFormatter *formatter = [[OnlyIntegerValueFormatter alloc] init];

    [NSApp beginSheet:window_panel modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
    [panel_lblwidth setStringValue:NSLocalizedString(@"CUSTOM_WIDTH", NULL)];
    [panel_lblheight setStringValue:NSLocalizedString(@"CUSTOM_HEIGHT", NULL)];
    [panel_btnok setTitle:NSLocalizedString(@"ALERT_OK", NULL)];
    [panel_btncancel setTitle:NSLocalizedString(@"ALERT_CANCEL", NULL)];
    [panel_lblratio setStringValue:@""];
    [panel_txtheight setStringValue:@""];
    [panel_txtwidth setStringValue:@""];
    [panel_txtwidth setFormatter:formatter];
    [panel_txtheight setFormatter:formatter];
 
    [window_panel setDefaultButtonCell:[panel_btncancel cell]];
     [window_panel makeFirstResponder:panel_txtwidth];
    [NSApp runModalForWindow:window_panel];   //This call blocks the execution until [NSApp stopModal] is called
    [NSApp endSheet:window_panel];
    [window_panel orderOut:self];
    
    [formatter release];
    
    NSString *sHeight = [panel_txtheight stringValue];
    if ([sHeight length] == 0)
    {
        return;
    }
    
    NSString *sWidth = [panel_txtwidth stringValue];
    if ([sWidth length] == 0)
    {
        return;
    }
    
    //todo: allready exists?
    
    


    ResolutionDataItem *rdi = [[ResolutionDataItem alloc] init];
    [rdi setWidth:[sWidth intValue]];
    [rdi setHeight:[sHeight intValue]];
    
    if (![customResolution addCustomResolution: rdi])
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText: NSLocalizedString(@"ERROR_ADD", NULL)];
        [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"ALERT_ERROR",NULL)];
        [alert runModal];
        [alert release];
    }
    else
    {
        // todo:
        // Force monitor to reload overrides
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText: NSLocalizedString(@"CUSTOM_ADD", NULL)];
        [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"ALERT_WARNING", NULL)];
        [alert runModal];
        [alert release];
        
        [window_list reloadData];
    }
    
    [rdi release];
}

- (IBAction)RemoveCustomResoultion:(id)sender
{
    if ([customResolution removeCustomResolution:[window_list itemAtRow:[window_list selectedRow]]] == false)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText: NSLocalizedString(@"ERROR_DEL", NULL)];
        [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"ALERT_ERROR", NULL)];
        [alert runModal];
        [alert release];
    }
    else
    {
        // todo:
        // Force monitor to reload overrides
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText: NSLocalizedString(@"CUSTOM_DEL", NULL)];
        [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"ALERT_WARNING", NULL)];
        [alert runModal];
        [alert release];
        
        [window_list reloadData];
    }
}

- (IBAction)PanelOk:(id)sender
{
    [NSApp stopModal];
}

- (IBAction)PanelCancel:(id)sender
{
    [panel_lblratio setStringValue:@""];
    [panel_txtheight setStringValue:@""];
    [panel_txtwidth setStringValue:@""];
    [NSApp stopModal];
}

- (IBAction)PaneltTXTChanged:(id)sender
{
    NSString *sHeight = [panel_txtheight stringValue];
     NSString *sWidth = [panel_txtwidth stringValue];
    if ([sHeight length] == 0 || [sWidth length] == 0)
    {
        [panel_lblratio setStringValue:@""];
        return;
    }
    
   
    int nWidth = [sWidth intValue];
    int nHeight = [sHeight intValue];
    
    int gcd = [ResolutionDataItem gcd:nWidth height:nHeight];
    [panel_lblratio setStringValue:[NSString stringWithFormat:@"%d:%d", nWidth/gcd, nHeight/gcd]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    [window_btndel setEnabled: ([customResolution isCustomItem: item])];
    return true;
}


-(size_t) getDepthFromPixelEncoding:(CFStringRef) pixelEncoding
{
    size_t depth = 0;
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
    return depth;
    
}

-(size_t) bitDepthCG:(CGDisplayModeRef) mode
{
    size_t depth = 0;
	CFStringRef pixelEncoding = CGDisplayModeCopyPixelEncoding(mode);
    depth = [self getDepthFromPixelEncoding:pixelEncoding];
    CFRelease(pixelEncoding);
    return depth;
}


-(size_t) bitDepthCGS:(CGDirectDisplayID) display
{
    size_t depth = 0;
    char *buffer = (char*)calloc(33, sizeof(char*));
    CGSGetDisplayPixelEncodingOfLength(display, buffer, 32);
    depth = [self getDepthFromPixelEncoding:(CFStringRef)[NSString stringWithFormat:@"%s", buffer]];
    free(buffer);
    return depth;
}



- (void)menuNeedsUpdate:(NSMenu *)menu
{
    [self releaseMenu:menu];
    
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
                if ([[monitors objectAtIndex:j] caseInsensitiveCompare:[monitors objectAtIndex:i]] == NSOrderedSame)
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
                name = [NSString stringWithFormat:@"%@ (%d)", [monitors objectAtIndex:i], index];
            else
                name = [monitors objectAtIndex:i];
            
            NSMenuItem *displayItem = [[NSMenuItem alloc] initWithTitle: name  action:nil keyEquivalent:@""];
            BOOL bActive = CGDisplayIsActive(displays[i]);
            if (bActive)
                [displayItem setState:NSOnState];
            else
                [displayItem setState:NSOffState];
            
            NSMenu *subMenu = [[NSMenu alloc] init];
            
            NSMenuItem *subItem;

            ResolutionDataSource *dataSource = [[ResolutionDataSource alloc] initWithDisplay:displays[i]];
            int numberOfDisplayModes = [dataSource outlineView:nil numberOfChildrenOfItem:nil];
            if (numberOfDisplayModes > 0)
            {
                int currentDisplayModeNumber;
                CGSGetCurrentDisplayMode(displays[i], &currentDisplayModeNumber);
                NSTableColumn *tableColumn = [[NSTableColumn alloc] init];
                [tableColumn setIdentifier:@"Name"];
                for (int j = 0; j < numberOfDisplayModes; j++)
                {
                    ResolutionDataItem *dataItem = [dataSource outlineView:nil child:j ofItem:nil];
                    if ([dataItem visible])
                    {
                        subItem = [[NSMenuItem alloc] initWithTitle: @"" action:@selector(MonitorResolution:)  keyEquivalent:@""];
                        
                        DisplayData *data = [[DisplayData alloc] init];
                        [data setMode:[dataItem mode]];
                        [data setDisplay:displays[i]];
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
                subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_DISABLE",@"") action:@selector(MonitorClicked:)  keyEquivalent:@""];
                DisplayData *data = [[DisplayData alloc] init];
                [data setDisplay:displays[i]];
                [subItem setRepresentedObject: data];
                [subMenu insertItem:subItem atIndex:0];
            }
            else
            {
                subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_ENABLE",@"") action:@selector(MonitorClicked:)  keyEquivalent:@""];
                DisplayData *data = [[DisplayData alloc] init];
                [data setDisplay:displays[i]];
                [subItem setRepresentedObject: data];
                [subMenu insertItem:subItem atIndex:0];
            }
            ;
            
           
            
            
            [subMenu insertItem:[[NSMenuItem separatorItem] copy] atIndex:1];
            
            [subMenu insertItem:[[NSMenuItem separatorItem] copy] atIndex:[[subMenu itemArray] count]];
             
            subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_MANAGE",@"")  action:@selector(ManageResolution:)  keyEquivalent:@""];
            DisplayData *data = [[DisplayData alloc] init];
            [data setDisplay:displays[i]];
            [subItem setRepresentedObject: data];
            [subMenu insertItem:subItem atIndex:[[subMenu itemArray] count]];
            
            [displayItem setSubmenu:subMenu];
            [statusMenu addItem:displayItem];

        }
        [monitors release];
        
    }
    else
    {
        NSMenuItem *noDisplays = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_NO_MONITOS",@"MENU_NO_MONITOS") action:nil keyEquivalent:@""];
        [statusMenu addItem:noDisplays];
        [noDisplays release];
    }
    
    [statusMenu addItem:[[NSMenuItem separatorItem] copy]];
    
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_DETECT",@"MENU_DETECT") action:@selector(DetectMonitors:) keyEquivalent:@""];
    [statusMenu addItem:menuItem];
}

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

-(void)awakeFromNib{
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusMenu setDelegate:self];
    [statusItem setMenu:statusMenu];
    [statusItem setImage:[NSImage imageNamed:@"status_icon.png"]];
    [statusItem setHighlightMode:YES];
    
    
}

@end
