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

#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
#import "CustomResolution.h"
#import "DisplayData.h"
@interface DisableMonitorAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, NSOutlineViewDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem *statusItem;
    NSMenuItem *menuItemLock;
    NSMenuItem *menuItemScreenSaver;
    NSMenuItem *menuItemQuit;
    CustomResolution *customResolution;
}

@property (assign) IBOutlet NSWindow *pref_window;
@property (assign) IBOutlet NSTextField *pref_lblHeader;
@property (assign) IBOutlet NSButton *pref_btnAdd;
@property (assign) IBOutlet NSButton *pref_btnDel;
@property (assign) IBOutlet NSButton *pref_btnClose;
@property (assign) IBOutlet NSOutlineView *pref_lstResolutions;
@property (assign) IBOutlet NSPanel *pref_CustomRes_window;
@property (assign) IBOutlet NSTextField *pref_CustomRes_lblWidth;
@property (assign) IBOutlet NSTextField *pref_CustomRes_lblHeight;
@property (assign) IBOutlet NSTextField *pref_CustomRes_txtWidth;
@property (assign) IBOutlet NSTextField *pref_CustomRes_txtHeight;
@property (assign) IBOutlet NSTextField *pref_CustomRes_lblRatio;
@property (assign) IBOutlet NSButton *pref_CustomRes_btnOk;
@property (assign) IBOutlet NSButton *pref_CustomRes_btnCancel;
@property (assign) IBOutlet NSPanel *about_window;
@property (assign) IBOutlet NSButton *about_btnUpdate;
@property (assign) IBOutlet NSButton *about_btnWeb;
@property (assign) IBOutlet NSTextField *about_lblAppName;
@property (assign) IBOutlet NSTextField *about_lblVersion;

@property (assign) CGDirectDisplayID window_display;
@property (assign) IBOutlet SUUpdater *updater;


+(NSMutableArray*) GetSortedDisplays;
+(void)ToggleMonitor:(DisplayData*) displayData enabled:(Boolean) enabled mirror:(Boolean)mirror;
@end
