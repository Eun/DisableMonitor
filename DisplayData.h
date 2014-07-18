//
//  DisplayData.h
//  DisableMonitor
//
//  Created by salzmann on 18.07.14.
//
//

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
} CGSDisplayMode;


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
}
@property CGSDisplayMode mode;
@property CGDirectDisplayID display;
@end
