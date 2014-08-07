//
//  ResoultionDataItem.m
//  DisableMonitor
//
//  Created by salzmann on 18.07.14.
//
//

#import "ResolutionDataItem.h"

@implementation ResolutionDataItem

- (id)initWithMode:(CGSDisplayMode)mode {
    self = [super init];
    if (self) {
        [self setMode:mode];
        [self setVisible:true];
    }
    return self;
}
- (void)dealloc {
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt32:self.mode.width forKey:@"RSMode_width"];
    [coder encodeInt32:self.mode.height forKey:@"RSMode_height"];
    [coder encodeInt32:self.mode.depth forKey:@"RSMode_depth"];
    [coder encodeInt32:self.mode.freq forKey:@"RSMode_freq"];
    [coder encodeInt32:self.visible forKey:@"RSVisible"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _mode.width = [coder decodeInt32ForKey:@"RSMode_width"];
        _mode.height = [coder decodeInt32ForKey:@"RSMode_height"];
        _mode.depth = [coder decodeInt32ForKey:@"RSMode_depth"];
        _mode.freq = [coder decodeInt32ForKey:@"RSMode_freq"];
        self.visible = [coder decodeInt32ForKey:@"RSVisible"];
    }
    return self;
}

+ (int) gcd:(int)width height:(int)height
{
    return (height == 0) ? width : [self gcd:height height:width%height];
}

- (void) setWidth:(uint32_t) width
{
    _mode.width = width;
}

- (void) setHeight:(uint32_t) height
{
    _mode.height = height;
}

@end
