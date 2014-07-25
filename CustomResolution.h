//
//  CustomResolution.h
//  DisableMonitor
//
//  Created by salzmann on 25.07.14.
//
//

#import <Foundation/Foundation.h>

@interface CustomResolution : NSObject
{
    CGDirectDisplayID displayID;
}
- (id)initWithDisplayID:(CGDirectDisplayID)aDisplay;
@end
