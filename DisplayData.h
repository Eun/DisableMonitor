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

#import <Foundation/Foundation.h>

typedef struct {
    uint32_t modeNumber;
    uint32_t flags;
    uint32_t width;
    uint32_t height;
    uint32_t depth;
    uint8_t unknown[170];
    uint16_t freq;
    uint8_t more_unknown[16];
    float density;
} CGSDisplayMode
;

extern AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);
extern io_service_t IOServicePortFromCGDisplayID(CGDirectDisplayID displayID);
extern CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef, CGDirectDisplayID, bool);
extern CGDisplayErr CGSGetDisplayList(CGDisplayCount maxDisplays, CGDirectDisplayID * onlineDspys, CGDisplayCount * dspyCnt);
extern void CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *nModes);
extern void CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx, CGSDisplayMode *mode, int length);
extern CGError CGSGetDisplayPixelEncodingOfLength(CGDirectDisplayID displayID, char *pixelEncoding, size_t length);
extern CGError CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);
extern CGError CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum);

@interface DisplayData : NSObject
{
    CGSDisplayMode mode;
    CGDirectDisplayID display;
    float brightness;
}
@property CGSDisplayMode mode;
@property CGDirectDisplayID display;
@property float brightness;
@end
