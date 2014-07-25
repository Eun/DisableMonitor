//
//  ResOutlineView.m
//  DisableMonitor
//
//  Created by salzmann on 18.07.14.
//
//

#import "ResOutlineView.h"

@implementation ResOutlineView


-(id)init
{
    self = [super init];
    if (self) {
        [self setDelegate:self];
    }
    
    return self;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setDelegate:self];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setDelegate:self];
    }
    return self;
}

@end
