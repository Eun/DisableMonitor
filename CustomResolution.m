//
//  CustomResolution.m
//  DisableMonitor
//
//  Created by salzmann on 25.07.14.
//
//

#import <Foundation/Foundation.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import "CustomResolution.h"
#import "DisplayData.h"

@implementation CustomResolution

- (id)initWithDisplayID:(CGDirectDisplayID)aDisplay {
    self = [super init];
    if (self) {
        displayID = aDisplay;
        
        [self ReadResolutions];
        
    }
    return self;
}
- (void)dealloc {
    [super dealloc];
}

- (void) ReadResolutions
{
    io_service_t service = IOServicePortFromCGDisplayID(displayID);
    if (service)
    {
        NSDictionary *deviceInfo = (NSDictionary *)IODisplayCreateInfoDictionary(service, kIODisplayOnlyPreferredName);
        NSNumber *displayVendorID = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayVendorID]];
        NSNumber *displayProductID = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductID]];
        
        NSString *filePath = [NSString  stringWithFormat:@"/System/Library/Displays/Overrides/DisplayVendorID-%x/DisplayProductID-%x", (int)[displayVendorID integerValue], (int)[displayProductID integerValue]];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
        {
            NSDictionary *displayDict = [[NSDictionary alloc] initWithContentsOfFile:filePath];
            NSArray *scaleResolutions = [displayDict objectForKey:@"scale-resolutions"];
            
            for (NSData *data in scaleResolutions)
            {
                NSData *data4 = [data subdataWithRange:NSMakeRange(0, 4)];
                int width = CFSwapInt32BigToHost(*(int*)([data4 bytes]));
                data4 = [data subdataWithRange:NSMakeRange(4, 4)];
                int height = CFSwapInt32BigToHost(*(int*)([data4 bytes]));
                data4 = [data subdataWithRange:NSMakeRange(8, 4)];
                int unknown = CFSwapInt32BigToHost(*(int*)([data4 bytes]));
                NSLog(@"%dx%dx%d", (int)width, (int)height, unknown);
                
            }
            
            [displayDict release];
        }
        
        [deviceInfo release];
    }
}

@end
