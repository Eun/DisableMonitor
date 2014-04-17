//
//  DisableMonitorAppDelegate.h
//  DisableMonitor
//
//  Created by Aravindkumar Rajendiran on 10-04-17.
//  Copyright 2010 Grapewave. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DisableMonitorAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate> {
    NSWindow *window;
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;

}

@property (assign) IBOutlet NSWindow *window;

@end
