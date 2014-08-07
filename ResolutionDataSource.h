//
//  ResolutionDataSource.h
//  DisableMonitor
//
//  Created by salzmann on 18.07.14.
//
//

#import <Foundation/Foundation.h>
#import "CustomResolution.h"

@interface ResolutionDataSource : NSObject  <NSOutlineViewDataSource>
{
    NSMutableArray *dataItems;
}
@property CGDirectDisplayID display;
- (id) initWithDisplay:(CGDirectDisplayID)aDisplay;

@end
