//
//  ResoultionDataItem.h
//  DisableMonitor
//
//  Created by salzmann on 18.07.14.
//
//

#import <Foundation/Foundation.h>
#import "DisplayData.h"

@interface ResolutionDataItem : NSObject
@property CGSDisplayMode mode;
@property Boolean visible;
- (id)initWithMode:(CGSDisplayMode)mode;
+ (int) gcd:(int)width height:(int)height;
- (void) setWidth:(uint32_t) width;
- (void) setHeight:(uint32_t) height;
@end
