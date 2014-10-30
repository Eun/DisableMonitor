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
#import "CustomResolution.h"
#import "OnlyIntegerValueFormatter.h"
#import "DisplayIDAndName.h"
#include <stdlib.h>

@implementation NSImage (NegativeImage)

- (NSImage *)negativeImage
{
    // get width and height as integers, since we'll be using them as
    // array subscripts, etc, and this'll save a whole lot of casting
    CGSize size = self.size;
    int width = size.width;
    int height = size.height;
    
    // Create a suitable RGB+alpha bitmap context in BGRA colour space
    CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *memoryPool = (unsigned char *)calloc(width*height*4, 1);
    CGContextRef context = CGBitmapContextCreate(memoryPool, width, height, 8, width * 4, colourSpace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colourSpace);
    
    // draw the current image to the newly created context
    
    CGImageSourceRef source;
    
    source = CGImageSourceCreateWithData((CFDataRef)[self TIFFRepresentation], NULL);
    CGImageRef maskRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), maskRef);
    
    // run through every pixel, a scan line at a time...
    for(int y = 0; y < height; y++)
    {
        // get a pointer to the start of this scan line
        unsigned char *linePointer = &memoryPool[y * width * 4];
        
        // step through the pixels one by one...
        for(int x = 0; x < width; x++)
        {
            // get RGB values. We're dealing with premultiplied alpha
            // here, so we need to divide by the alpha channel (if it
            // isn't zero, of course) to get uninflected RGB. We
            // multiply by 255 to keep precision while still using
            // integers
            int r, g, b;
            if(linePointer[3])
            {
                r = linePointer[0] * 255 / linePointer[3];
                g = linePointer[1] * 255 / linePointer[3];
                b = linePointer[2] * 255 / linePointer[3];
            }
            else
                r = g = b = 0;
            
            // perform the colour inversion
            r = 255 - r;
            g = 255 - g;
            b = 255 - b;
            
            // multiply by alpha again, divide by 255 to undo the
            // scaling before, store the new values and advance
            // the pointer we're reading pixel data from
            linePointer[0] = r * linePointer[3] / 255;
            linePointer[1] = g * linePointer[3] / 255;
            linePointer[2] = b * linePointer[3] / 255;
            linePointer += 4;
        }
    }
    
    // get a CG image from the context, wrap that into a
    // UIImage
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    NSImage *returnImage = [[NSImage alloc] initWithCGImage:cgImage size: NSZeroSize];
    // clean up
    CGImageRelease(cgImage);
    CGContextRelease(context);
    free(memoryPool);
    
    // and return
    return returnImage;
}

@end

@implementation DisableMonitorAppDelegate

@synthesize pref_window;
@synthesize pref_lblHeader;
@synthesize pref_btnAdd;
@synthesize pref_btnDel;
@synthesize pref_btnClose;
@synthesize pref_lstResolutions;
@synthesize pref_CustomRes_window;
@synthesize pref_CustomRes_lblWidth;
@synthesize pref_CustomRes_lblHeight;
@synthesize pref_CustomRes_txtWidth;
@synthesize pref_CustomRes_txtHeight;
@synthesize pref_CustomRes_lblRatio;
@synthesize pref_CustomRes_btnOk;
@synthesize pref_CustomRes_btnCancel;
@synthesize about_window;
@synthesize about_btnUpdate;
@synthesize about_btnWeb;
@synthesize about_lblAppName;
@synthesize about_lblVersion;

@synthesize window_display;
@synthesize updater;


CFStringRef const kDisplayBrightness = CFSTR(kIODisplayBrightnessKey);

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
    
}


+(NSString*) screenNameForDisplay:(CGDirectDisplayID)displayID
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

+(NSMutableArray*) GetSortedDisplays
{
    NSArray *displays = nil;
    CGDisplayCount nDisplays = 0;
    
    CGDirectDisplayID displayList[0x10];
    NSMutableArray *displayArray = [[NSMutableArray alloc] init];
    CGDisplayErr err = CGSGetDisplayList(0x10, displayList, &nDisplays);
    
    if (err == 0 && nDisplays > 0)
    {
        for (int i = 0; i < nDisplays; i++)
        {
            [displayArray addObject: [NSNumber numberWithUnsignedInt:displayList[i]]];
        }
        
        displays = [displayArray sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            CGDirectDisplayID _a = [a unsignedIntValue], _b = [b unsignedIntValue];
            if (_a == _b)
                return NSOrderedSame;
            else if (_a < _b)
                return NSOrderedAscending;
            else
                return NSOrderedDescending;
        }];
    }
    
    
    
    if (nDisplays > 0)
    {
        NSMutableArray *monitors = [[NSMutableArray alloc] init];
        for (int i = 0; i < nDisplays; i++)
        {
            NSString *name = [DisableMonitorAppDelegate screenNameForDisplay:[[displays objectAtIndex:i] unsignedIntValue]];
            if (name != nil)
            {
                [monitors addObject: name];
            }
            
            else
            {
                [monitors addObject: [NSString stringWithFormat:@"Display #%d", i + 1]];
            }
        }
        
        NSMutableArray *retDisplays = [[NSMutableArray alloc] init];
        for (int i = 0; i < monitors.count; i++)
        {
            int num = 0;
            int index = 1;
            
            if (!CGDisplayIsOnline([[displays objectAtIndex:i] unsignedIntValue]))
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
            
            
            DisplayIDAndName *idAndName = [[DisplayIDAndName alloc] init];
            [idAndName setId:[[displays objectAtIndex:i] unsignedIntValue]];
            [idAndName setName:name];
            [retDisplays addObject:idAndName];
        }
        [monitors release];
        return retDisplays;
    }
    else
    {
        return nil;
    }
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

+(void)MoveAllWindows:(CGDirectDisplayID) display to:(CGDirectDisplayID*)todisplay
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

void BrightnessRead(IOI2CConnectRef connect)
{
    kern_return_t kr;
    IOI2CRequest request;
    UInt8 data[128];
    UInt8 inData[9];
    int i;
    
    bzero( &request, sizeof(request));
    
    request.commFlags = 0;
    
    request.sendAddress = 0x6E;
    request.sendTransactionType = kIOI2CSimpleTransactionType;
    request.sendBuffer = (vm_address_t) &data[0];
    request.sendBytes = 5;
    request.minReplyDelay = 6000000;
    
    data[0] = 0x51;
    data[1] = 0x82;
    data[2] = 0x01;
    data[3] = 0x10;
    data[4] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3];
    
    
    request.replyTransactionType = kIOI2CDDCciReplyTransactionType;
    request.replyAddress = 0x6F;
    request.replySubAddress = 0x51;
    request.replyBuffer = (vm_address_t) &inData[0];
    request.replyBytes = 9;
    bzero( &inData[0], request.replyBytes );
    
    kr = IOI2CSendRequest( connect, kNilOptions, &request );
    assert( kIOReturnSuccess == kr );
    if( kIOReturnSuccess != request.result)
        return;
    
    
    for (i=0; i<9; i++) {
        
        printf(" 0x%x ",inData[i]);
    }
    printf("n");
}

void SetBrightness(IOI2CConnectRef connect, int bright)
{
    kern_return_t kr;
    IOI2CRequest request;
    UInt8 data[128];
    
    bzero( &request, sizeof(request));
    
    request.commFlags = 0;
    
    request.sendAddress = 0x6E;
    request.sendTransactionType = kIOI2CSimpleTransactionType;
    request.sendBuffer = (vm_address_t) &data[0];
    request.sendBytes = 7;
    
    data[0] = 0x51;
    data[1] = 0x84;
    data[2] = 0x03;
    data[3] = 0x10;
    data[4] = 0x64 ;
    data[5] = bright;
    data[6] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3]^ data[4]^
    data[5];
    
    
    request.replyTransactionType = kIOI2CNoTransactionType;
    request.replyBytes = 0;//128;
    
    kr = IOI2CSendRequest( connect, kNilOptions, &request );
    assert( kIOReturnSuccess == kr );
    if( kIOReturnSuccess != request.result)
        return;

}

extern bool DisplayServicesCanChangeBrightness(CGDirectDisplayID display);
extern CGError DisplayServicesSetBrightness(CGDirectDisplayID display, float brightnss);
extern void DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightnss);
+(void)ToggleMonitor:(DisplayData*) displayData enabled:(Boolean) enabled mirror:(Boolean)mirror
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
                    if (displays[i] == [displayData display])
                        continue;
                    if (!CGDisplayIsOnline(displays[i]))
                        continue;
                    if (!CGDisplayIsActive(displays[i]))
                        continue;
                    @try {
                        [self MoveAllWindows:[displayData display] to:displays[i]];
                    }
                    @catch (NSException *e)
                    {
                        NSLog(@"Problems in moving windows");
                    }
                    break;
                }
            }
        }

       
       
        /*if (DisplayServicesCanChangeBrightness([displayData display]))
        {
            if (enabled == false)
            {
                float brightness = 0.0;
                DisplayServicesGetBrightness([displayData display], &brightness);
                [displayData setBrightness:brightness];
                DisplayServicesSetBrightness([displayData display], 0.0f);
            }
            else
            {
                DisplayServicesSetBrightness([displayData display], [displayData brightness]);
            }
        }
        else
        {
            io_service_t service = CGDisplayIOServicePort([displayData display]);
            if (service)
            {
                IOItemCount count;
                io_string_t pathName;
                if (IORegistryEntryGetPath(service, kIOServicePlane, pathName) == KERN_SUCCESS)
                {
                    IORegistryEntrySetCFProperty
                    if (IOFBGetI2CInterfaceCount(service, &count) == kIOReturnSuccess)
                    {
                        for (int i = 0; i < count; ++i )
                        {
                            IOI2CConnectRef connect;
                            io_service_t interface;
                            if (IOFBCopyI2CInterfaceForBus(service, i, &interface) != kIOReturnSuccess)
                                continue;
                            kern_return_t kr = IOI2CInterfaceOpen(interface, kNilOptions, &connect );
                            IOObjectRelease(interface);
                            if(kIOReturnSuccess == kr)
                            {
                                
                                BrightnessRead(connect);
                                IOI2CInterfaceClose(connect, kNilOptions );
                                break;
                            }
                        }
                    }
                }
            }
        }*/
    
        
        
        
        err = CGBeginDisplayConfiguration (&config);
        if (err != 0)
        {
            ShowError(@"Error in CGBeginDisplayConfiguration: %d",err);
            return;
        }
        if (mirror && enabled == false)
        {
            CGConfigureDisplayMirrorOfDisplay(config, [displayData display], kCGNullDirectDisplay);
        }
        
        err = CGSConfigureDisplayEnabled(config, [displayData display], enabled);
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
        
        // reset the wallpapers (Issue #10) - On hold while waiting for comment on GitHub
        /*
        NSArray *screens = [NSScreen screens];
        for (NSScreen *screen in screens) {
            NSURL *url = [[NSWorkspace sharedWorkspace] desktopImageURLForScreen:screen];
            NSDictionary *options = [[NSWorkspace sharedWorkspace] desktopImageOptionsForScreen:screen];
            [[NSWorkspace sharedWorkspace] setDesktopImageURL:url forScreen:screen options:options error:nil];
        }
        */
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
    CGDirectDisplayID displayId = [(DisplayData*)[item representedObject] display];
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

    
    if (bMirror == NO && bActive == true)
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
        [DisableMonitorAppDelegate ToggleMonitor:(DisplayData*)[item representedObject] enabled:!bActive mirror:bMirror];
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

-(void)TurnOffMonitors:(id) sender
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

-(void)StartScreenSaver:(id) sender
{
    [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/Frameworks/ScreenSaver.framework/Versions/A/Resources/ScreenSaverEngine.app"];
}

-(void)ShowAboutDialog:(id) sender
{
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    [about_window setTitle: NSLocalizedString(@"MENU_ABOUT", NULL)];
    [about_window setDelegate:self];
    [about_window makeKeyAndOrderFront:self];
    [about_window setLevel:NSFloatingWindowLevel];
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
    [about_window makeFirstResponder: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CloseAboutDialog) name:NSWindowDidResignMainNotification object:about_window];
    
}

-(void)CloseAboutDialog
{
    [about_window close];
}

-(void)Quit:(id) sender
{
    [NSApp terminate: nil];
}

-(IBAction)GotoHomePage:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/Eun/DisableMonitor"]];
}

-(IBAction)CheckForUpdates:(id)sender
{
    [updater checkForUpdates:sender];
}




-(void)ManageResolution:(id) sender
{
    [about_window close];
    NSMenuItem * item = (NSMenuItem*)sender;
    
    CGDirectDisplayID display = [(DisplayData*)[item representedObject] display];
    
    ProcessSerialNumber psn = { 0, kCurrentProcess };
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    
    if (CGDisplayIsOnline(display) && CGDisplayIsActive(display))
    {
        window_display = display;
        customResolution = [[CustomResolution alloc] initWithDisplayID:window_display];
        [pref_window setTitle: [[item parentItem] title]];
        [pref_window setDelegate:self];
        [pref_window makeKeyAndOrderFront:self];
        [pref_window setLevel:NSFloatingWindowLevel];
        [pref_lstResolutions setDataSource:[[ResolutionDataSource alloc] initWithDisplay:display]];
        [pref_lstResolutions setDelegate:self];
        [pref_lblHeader setStringValue:NSLocalizedString(@"CUSTOM_LABEL", NULL)];
        [pref_btnClose setTitle:NSLocalizedString(@"ALERT_CANCEL", NULL)];
        [pref_btnClose sizeToFit];
        [pref_btnClose setFrameOrigin: NSMakePoint(
                                                     
                                                     [pref_window frame].size.width -
                                                     [pref_btnClose frame].size.width
                                                     - 13
                                                     , [pref_btnClose frame].origin.y)];
        
        [pref_window makeFirstResponder: nil];
    }
    
}

- (void)windowWillClose:(NSNotification *)notification {
    ProcessSerialNumber psn = { 0, kCurrentProcess };
	TransformProcessType(&psn, 2 /*kProcessTransformToBackgroundApplication*/);
    if (customResolution != nil)
    {
        [customResolution release];
        customResolution = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)AddCustomResoultion:(id)sender
{
    OnlyIntegerValueFormatter *formatter = [[OnlyIntegerValueFormatter alloc] init];

    [NSApp beginSheet:pref_CustomRes_window modalForWindow:pref_window modalDelegate:nil didEndSelector:nil contextInfo:nil];
    [pref_CustomRes_lblWidth setStringValue:NSLocalizedString(@"CUSTOM_WIDTH", NULL)];
    [pref_CustomRes_lblHeight setStringValue:NSLocalizedString(@"CUSTOM_HEIGHT", NULL)];
    [pref_CustomRes_btnOk setTitle:NSLocalizedString(@"ALERT_OK", NULL)];
    [pref_CustomRes_btnCancel setTitle:NSLocalizedString(@"ALERT_CANCEL", NULL)];
    [pref_CustomRes_lblRatio setStringValue:@""];
    [pref_CustomRes_txtHeight setStringValue:@""];
    [pref_CustomRes_txtHeight setFormatter:formatter];
    [pref_CustomRes_txtWidth setStringValue:@""];
    [pref_CustomRes_txtWidth setFormatter:formatter];

 
    [pref_CustomRes_window setDefaultButtonCell:[pref_CustomRes_btnCancel cell]];
    [pref_CustomRes_window makeFirstResponder:pref_CustomRes_txtWidth];
    [NSApp runModalForWindow:pref_CustomRes_window];   //This call blocks the execution until [NSApp stopModal] is called
    [NSApp endSheet:pref_CustomRes_window];
    [pref_CustomRes_window orderOut:self];
    
    [formatter release];
    
    NSString *sHeight = [pref_CustomRes_txtHeight stringValue];
    if ([sHeight length] == 0)
    {
        return;
    }
    
    NSString *sWidth = [pref_CustomRes_txtWidth stringValue];
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
        
        [pref_lstResolutions reloadData];
    }
    
    [rdi release];
}

- (IBAction)RemoveCustomResoultion:(id)sender
{
    if ([customResolution removeCustomResolution:[pref_lstResolutions itemAtRow:[pref_lstResolutions selectedRow]]] == false)
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
        
        [pref_lstResolutions reloadData];
    }
}

- (IBAction)PanelOk:(id)sender
{
    [NSApp stopModal];
}

- (IBAction)PanelCancel:(id)sender
{
    [pref_CustomRes_lblRatio setStringValue:@""];
    [pref_CustomRes_txtHeight setStringValue:@""];
    [pref_CustomRes_txtWidth setStringValue:@""];
    [NSApp stopModal];
}


- (IBAction)CloseWindow:(id)sender
{
    [pref_window close];
}

- (IBAction)PaneltTXTChanged:(id)sender
{
    NSString *sHeight = [pref_CustomRes_txtHeight stringValue];
    NSString *sWidth = [pref_CustomRes_txtWidth stringValue];
    if ([sHeight length] == 0 || [sWidth length] == 0)
    {
        [pref_CustomRes_lblRatio setStringValue:@""];
        return;
    }
    
   
    int nWidth = [sWidth intValue];
    int nHeight = [sHeight intValue];
    
    int gcd = [ResolutionDataItem gcd:nWidth height:nHeight];
    [pref_CustomRes_lblRatio setStringValue:[NSString stringWithFormat:@"%d:%d", nWidth/gcd, nHeight/gcd]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    [pref_btnDel setEnabled: ([customResolution isCustomItem: item])];
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
    
    NSMutableArray *dict = [DisableMonitorAppDelegate GetSortedDisplays];
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
                        subItem = [[NSMenuItem alloc] initWithTitle: @"" action:@selector(MonitorResolution:)  keyEquivalent:@""];
                        
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
                subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_DISABLE",NULL) action:@selector(MonitorClicked:)  keyEquivalent:@""];
                DisplayData *data = [[DisplayData alloc] init];
                [data setDisplay:displayId];
                [subItem setRepresentedObject: data];
                [subMenu insertItem:subItem atIndex:0];
            }
            else
            {
                subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_ENABLE",NULL) action:@selector(MonitorClicked:)  keyEquivalent:@""];
                DisplayData *data = [[DisplayData alloc] init];
                [data setDisplay:displayId];
                [subItem setRepresentedObject: data];
                [subMenu insertItem:subItem atIndex:0];
            }
            
            
            
            if (bActive && bMirror == NO)
            {
                [subMenu insertItem:[[NSMenuItem separatorItem] copy] atIndex:[[subMenu itemArray] count]];
                
                subItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"MENU_MANAGE",NULL)  action:@selector(ManageResolution:)  keyEquivalent:@""];
                DisplayData *data = [[DisplayData alloc] init];
                [data setDisplay:displayId];
                [subItem setRepresentedObject: data];
                [subItem setOffStateImage:[NSImage imageNamed: NSImageNameSmartBadgeTemplate]];
                [subMenu insertItem:subItem atIndex:[[subMenu itemArray] count]];
            }
            
            [displayItem setSubmenu:subMenu];
            [statusMenu addItem:displayItem];
            [idAndName release];
        }
        [dict release];
    }
    
    
    
    [statusMenu addItem:[[NSMenuItem separatorItem] copy]];
    

    
    menuItemLock = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_TURNOFF",NULL) action:@selector(TurnOffMonitors:) keyEquivalent:@""];
    [menuItemLock setOffStateImage:[NSImage imageNamed: NSImageNameLockLockedTemplate]];
    [statusMenu addItem:menuItemLock];
    
    menuItemScreenSaver = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_SCREENSAVER",NULL) action:@selector(StartScreenSaver:) keyEquivalent:@""];
    [menuItemScreenSaver setOffStateImage:[NSImage imageNamed: NSImageNameLockLockedTemplate]];
    [menuItemScreenSaver setHidden:YES];
    [statusMenu addItem:menuItemScreenSaver];
    
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_DETECT",NULL) action:@selector(DetectMonitors:) keyEquivalent:@""];
    [menuItem setOffStateImage:[NSImage imageNamed: NSImageNameRefreshTemplate]];
    [statusMenu addItem:menuItem];
    
    [statusMenu addItem:[[NSMenuItem separatorItem] copy]];
    
    menuItem = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_ABOUT",NULL) action:@selector(ShowAboutDialog:) keyEquivalent:@""];
    [statusMenu addItem:menuItem];
    
    menuItemQuit = [[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"MENU_QUIT",NULL) action:@selector(Quit:) keyEquivalent:@""];
    [menuItemQuit setHidden:YES];
    [statusMenu addItem:menuItemQuit];

    NSTimer *t = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(updateMenu:) userInfo:statusMenu repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:t forMode:NSEventTrackingRunLoopMode];
}

- (void)updateMenu:(NSTimer *)t {
    
    // Get global modifier key flag, [[NSApp currentEvent] modifierFlags] doesn't update while menus are down
    CGEventRef event = CGEventCreate (NULL);
    CGEventFlags flags = CGEventGetFlags (event);
    BOOL optionKeyIsPressed = (flags & kCGEventFlagMaskAlternate) == kCGEventFlagMaskAlternate;
    CFRelease(event);
    
    [menuItemLock setHidden:optionKeyIsPressed];
    [menuItemScreenSaver setHidden:!optionKeyIsPressed];
    [menuItemQuit setHidden:!optionKeyIsPressed];
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


- (NSImage *)imageResize:(NSImage*)anImage newSize:(NSSize)newSize {
    NSImage *sourceImage = anImage;
    [sourceImage setScalesWhenResized:YES];
    
    // Report an error if the source isn't a valid image
    if (![sourceImage isValid]){
        NSLog(@"Invalid Image");
    } else {
        NSImage *smallImage = [[NSImage alloc] initWithSize: newSize];
        [smallImage lockFocus];
        [sourceImage setSize: newSize];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [sourceImage drawAtPoint:NSZeroPoint fromRect:CGRectMake(0, 0, newSize.width, newSize.height) operation:NSCompositeCopy fraction:1.0];
        [smallImage unlockFocus];
        return smallImage;
    }
    return nil;
}


- (BOOL)isInDarkMode
{
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] persistentDomainForName:NSGlobalDomain];
    id style = [dict objectForKey:@"AppleInterfaceStyle"];
    return ( style && [style isKindOfClass:[NSString class]] && NSOrderedSame == [style caseInsensitiveCompare:@"dark"] );
}

-(void)darkModeChanged:(NSNotification *)notif
{
    NSImage *statusImage = [self imageResize:[[NSImage imageNamed:@"icon.icns"] copy] newSize:NSMakeSize(20, 20)];
    
    if ([self isInDarkMode])
    {
        NSImage *normalImage = statusImage;
        statusImage = [normalImage negativeImage];
        [normalImage release];
    }
    
    [statusItem setImage:statusImage];
}



-(void)awakeFromNib{
    customResolution = nil;
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusMenu setDelegate:self];
    [statusItem setMenu:statusMenu];
    NSImage *statusImage = [self imageResize:[[NSImage imageNamed:@"icon.icns"] copy] newSize:NSMakeSize(20, 20)];
    
    if ([self isInDarkMode])
    {
        NSImage *normalImage = statusImage;
        statusImage = [normalImage negativeImage];
        [normalImage release];
    }
    
    [statusItem setImage:statusImage];
    [statusItem setHighlightMode:YES];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeChanged:) name:@"AppleInterfaceThemeChangedNotification" object:nil];

    
    
}

@end
