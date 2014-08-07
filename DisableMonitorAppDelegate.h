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
#import "CustomResolution.h"
@interface DisableMonitorAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, NSOutlineViewDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
    CustomResolution* customResolution;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *window_label;
@property (assign) IBOutlet NSButton *window_btnadd;
@property (assign) IBOutlet NSButton *window_btndel;
@property (assign) IBOutlet NSButton *window_btnclose;
@property (assign) IBOutlet NSOutlineView *window_list;
@property (assign) CGDirectDisplayID window_display;
@property (assign) IBOutlet NSPanel *window_panel;
@property (assign) IBOutlet NSTextField *panel_lblwidth;
@property (assign) IBOutlet NSTextField *panel_lblheight;
@property (assign) IBOutlet NSTextField *panel_txtwidth;
@property (assign) IBOutlet NSTextField *panel_txtheight;
@property (assign) IBOutlet NSTextField *panel_lblratio;
@property (assign) IBOutlet NSButton *panel_btnok;
@property (assign) IBOutlet NSButton *panel_btncancel;

@end
