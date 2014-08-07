//
//  CustomResolution.h
//  DisableMonitor
//
//  Created by salzmann on 25.07.14.
//
//

#import <Foundation/Foundation.h>
#import "ResolutionDataItem.h"

@interface CustomResolution : NSObject
{
    CGDirectDisplayID displayID;
    NSMutableArray *resolutions;
}
- (id)initWithDisplayID:(CGDirectDisplayID)aDisplay;
- (bool) isCustomItem:(ResolutionDataItem*)item;
- (bool) addCustomResolution:(ResolutionDataItem*)item;
- (bool) removeCustomResolution:(ResolutionDataItem*)item;
@end
