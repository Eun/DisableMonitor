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
@property Boolean custom;
@property uint32_t width, height, freq, depth;
- (id)initWithMode:(CGSDisplayMode)mode;
+ (int) gcd:(int)width height:(int)height;
@end
