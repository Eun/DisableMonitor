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

#import "DisplayIDAndNameCondition.h"

@implementation DisplayIDAndNameCondition
- (id) initWithDisplayIDAndName:(DisplayIDAndName*)displayIDAndName
{
        self = [super init];
        if (self) {
            [self setId:[displayIDAndName id]];
            [self setName:[displayIDAndName name]];
            [self setEnabled:false];
            [self setDisabled:false];
        }
        return self;
}


- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt32:self.id forKey:@"id"];
    [coder encodeBool:self.enabled forKey:@"enabled"];
    [coder encodeBool:self.disabled forKey:@"disabled"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.id = [coder decodeInt32ForKey:@"id"];
        self.enabled = [coder decodeBoolForKey:@"enabled"];
        self.disabled = [coder decodeBoolForKey:@"disabled"];
    }
    return self;
}

@end
