/**
 * DisableMonitor, Disable Monitors on Mac
 *
 * Copyright (C) 2014 Tobias Salzmann
 *
 * DisableMonitor is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 2 of the
 * License, or (at your option) any later version.
 *
 * DisableMonitor is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License for more details. You should have received a copy of the GNU
 * General Public License along with DisableMonitor. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Tobias Salzmann
 */

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
