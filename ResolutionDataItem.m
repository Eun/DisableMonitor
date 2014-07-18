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
        [self setCustom:false];
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
    [coder encodeInt32:self.custom forKey:@"RSCustom"];
    [coder encodeInt32:self.visible forKey:@"RSVisible"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.width = [coder decodeInt32ForKey:@"RSMode_width"];
        self.height = [coder decodeInt32ForKey:@"RSMode_height"];
        self.depth = [coder decodeInt32ForKey:@"RSMode_depth"];
        self.freq = [coder decodeInt32ForKey:@"RSMode_freq"];
        self.custom = [coder decodeInt32ForKey:@"RSCustom"];
        self.visible = [coder decodeInt32ForKey:@"RSVisible"];
    }
    return self;
}

@end
