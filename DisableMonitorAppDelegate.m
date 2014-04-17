//
//  DisableMonitorAppDelegate.m
//  DisableMonitor
//
//  Created by Aravindkumar Rajendiran on 10-04-17.
//  Copyright 2010 Grapewave. All rights reserved.
//

#import "DisableMonitorAppDelegate.h"
#import <IOKit/graphics/IOGraphicsLib.h>

@implementation DisableMonitorAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}


extern io_service_t IOServicePortFromCGDisplayID(CGDirectDisplayID displayID);
extern CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef, CGDirectDisplayID, bool);

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

-(void)ToggleMonitor:(CGDirectDisplayID) display enabled:(Boolean) enabled
{
    CGError err;
    CGDisplayConfigRef config;
    @try {
        err = CGBeginDisplayConfiguration (&config);
        if (err != 0)
        {
            NSLog(@"Error in CGBeginDisplayConfiguration: %d\n", err);
            return;
        }
        err = CGSConfigureDisplayEnabled(config, display, enabled);
        if (err != 0)
        {
            NSLog(@"Error in CGSConfigureDisplayEnabled: %d\n", err);
            return;
        }
        err = CGCompleteDisplayConfiguration(config, kCGConfigurePermanently);
        if (err != 0)
        {
            NSLog(@"Error in CGCompleteDisplayConfiguration: %d\n", err);
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
    Boolean active = CGDisplayIsActive(display);
    
    if (active == true)
    {
        CGDirectDisplayID    displays[0x10];
        CGDisplayCount  nDisplays = 0;
        CGError err = CGGetActiveDisplayList(0x10, displays, &nDisplays);
        
        if (err == 0 && nDisplays - 1 == 0)
        {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setInformativeText:@"You are disabling your last active monitor, you wont be able to see anything continue?"];
            [alert addButtonWithTitle:@"OK"];
            [alert addButtonWithTitle:@"Cancel"];
            [alert setAlertStyle:NSCriticalAlertStyle];
            [alert setMessageText:@"Warning"];
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


-(void)DetectMonitors:(id) sender
{
    CGDirectDisplayID    displays[0x10];
    CGDisplayCount  dspCount = 0;
    
    if (CGSGetDisplayList(0x10, displays, &dspCount) == noErr)
    {
        for(int i = 0; i < dspCount; i++)
        {
            io_service_t service = IOServicePortFromCGDisplayID(displays[i]);
            if (service)
                IOServiceRequestProbe(service, kIOFBUserRequestProbe);
        }
    }
}


- (void)menuNeedsUpdate:(NSMenu *)menu
{
    
    [statusMenu removeAllItems];
    CGDirectDisplayID    displays[0x10];
    CGDisplayCount  nDisplays = 0;
    
    CGDisplayErr err = CGSGetDisplayList(0x10, displays, &nDisplays);
    
    if (err == 0 && nDisplays > 0)
    {
        NSMutableArray *monitors = [[NSMutableArray alloc] init];
        NSMutableArray *monitorIDs = [[NSMutableArray alloc] init];
        for (int i = 0; i < nDisplays; i++)
        {
            NSString *name = screenNameForDisplay(displays[i]);
            if (name != nil)
            {
                [monitors addObject: name];
                [monitorIDs addObject:[NSNumber numberWithInt:(CGDirectDisplayID)displays[i]]];
                
                
            }
        }
        
        for (int i = 0; i < monitors.count; i++)
        {
            int num = 0;
            int index = 1;
            
            
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
            
            NSMenuItem *displayItem = [[NSMenuItem alloc] initWithTitle: name  action:@selector(MonitorClicked:) keyEquivalent:@""];
            if (CGDisplayIsActive(displays[i]))
                [displayItem setState:NSOnState];
            else
                [displayItem setState:NSOffState];
            [displayItem setTag:displays[i]];
            [statusMenu addItem:displayItem];
            [displayItem release];

        }
        [monitors release];
        [monitorIDs release];
        
    }
    else
    {
        NSMenuItem *noDisplays = [[NSMenuItem alloc] initWithTitle: @"No Displays Detected" action:nil keyEquivalent:@""];
        [statusMenu addItem:noDisplays];
        [noDisplays release];
    }
    
    [statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle: @"Detect Monitors" action:@selector(DetectMonitors:) keyEquivalent:@""];
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
