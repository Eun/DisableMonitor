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

#import "MonitorDataSource.h"
#import <IOKit/i2c/IOI2CInterface.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import "DisplayIDAndNameCondition.h"
#import "ResolutionDataSource.h"
#include <stdlib.h>

@implementation MonitorDataSource
@synthesize display;

+(NSString*) screenNameForDisplay:(CGDirectDisplayID)displayID
{
    NSString *screenName = nil;
    io_service_t service = IOServicePortFromCGDisplayID(displayID);
    if (service)
    {
        NSDictionary *deviceInfo = (NSDictionary *)IODisplayCreateInfoDictionary(service, kIODisplayOnlyPreferredName);
        NSDictionary *localizedNames = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductName]];
        
        if ([localizedNames count] > 0) {
            screenName = [[localizedNames objectForKey:[[localizedNames allKeys] objectAtIndex:0]] retain];
        }
        
        [deviceInfo release];
    }
    return [screenName autorelease];
}

+(NSMutableArray*) GetSortedDisplays
{
    return [self GetSortedDisplays:NULL];
}

+(NSMutableArray*) GetSortedDisplays:(CGDirectDisplayID)skipDisplayID
{
    NSArray *displays = nil;
    CGDisplayCount nDisplays = 0;
    
    CGDirectDisplayID displayList[0x10];
    NSMutableArray *displayArray = [[NSMutableArray alloc] init];
    CGDisplayErr err = CGSGetDisplayList(0x10, displayList, &nDisplays);
    
    if (err == 0 && nDisplays > 0)
    {
        for (int i = 0; i < nDisplays; i++)
        {
            [displayArray addObject: [NSNumber numberWithUnsignedInt:displayList[i]]];
        }
        
        displays = [displayArray sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            CGDirectDisplayID _a = [a unsignedIntValue], _b = [b unsignedIntValue];
            if (_a == _b)
                return NSOrderedSame;
            else if (_a < _b)
                return NSOrderedAscending;
            else
                return NSOrderedDescending;
        }];
        nDisplays = [displays count];
    }
    
    
    
    if (nDisplays > 0)
    {
        NSMutableArray *monitors = [[NSMutableArray alloc] init];
        for (int i = 0; i < nDisplays; i++)
        {
            NSString *name = [MonitorDataSource screenNameForDisplay:[[displays objectAtIndex:i] unsignedIntValue]];
            if (name != nil)
            {
                [monitors addObject: name];
            }
            
            else
            {
                [monitors addObject: [NSString stringWithFormat:@"Display #%d", i + 1]];
            }
        }
        
        NSMutableArray *retDisplays = [[NSMutableArray alloc] init];
        for (int i = 0; i < monitors.count; i++)
        {
            int num = 0;
            int index = 1;
            
            if (!CGDisplayIsOnline([[displays objectAtIndex:i] unsignedIntValue]))
                continue;
            
            for (int j = 0; j < monitors.count; j++)
            {
                if ([[monitors objectAtIndex:j] caseInsensitiveCompare:[monitors objectAtIndex:i]] == NSOrderedSame)
                {
                    num++;
                    if (j < i)
                    {
                        index++;
                    }
                }
            }
            
            if ([[displays objectAtIndex:i] unsignedIntValue] == skipDisplayID)
                continue;
            NSString *name;
            if (num > 1)
                name = [NSString stringWithFormat:@"%@ (%d)", [monitors objectAtIndex:i], index];
            else
                name = [monitors objectAtIndex:i];
            
            
            DisplayIDAndName *idAndName = [[DisplayIDAndName alloc] init];
            [idAndName setId:[[displays objectAtIndex:i] unsignedIntValue]];
            [idAndName setName:[name retain]];
            [retDisplays addObject:idAndName];
        }
        [monitors release];
        return retDisplays;
    }
    else
    {
        return nil;
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item != nil)
        return 0;

    if (dataItems == nil)
    {
        NSMutableArray* availableDisplays = [MonitorDataSource GetSortedDisplays:display];
        dataItems = [[NSMutableArray alloc] init];
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *dict = [ResolutionDataSource getDictForDisplay:userDefaults display:display];
        NSMutableArray *items = nil;
        if ([dict count] > 0)
        {
            items = [dict objectForKey:listToUse];
        }
        
        // add all monitors that are available
        for (int i = [availableDisplays count] - 1; i>= 0; --i)
        {
            DisplayIDAndNameCondition *item_display = [[DisplayIDAndNameCondition alloc] initWithDisplayIDAndName:[availableDisplays objectAtIndex:i]];
            for (int j = [items count] - 1; j>= 0; --j)
            {
                DisplayIDAndNameCondition *store_item =[NSKeyedUnarchiver unarchiveObjectWithData:[items objectAtIndex:i]];
                if ([item_display id] == [store_item id])
                {
                    [item_display setEnabled:[store_item enabled]];
                    [item_display setDisabled:[store_item disabled]];
                    break;
                }
            }
            [dataItems addObject:item_display];
        }
        
        // add all monitors that are not connected
        for (int i = [items count] - 1; i>= 0; --i)
        {
            DisplayIDAndNameCondition *store_item =[NSKeyedUnarchiver unarchiveObjectWithData:[items objectAtIndex:i]];
            bool isInList = false;
            for (int j = [dataItems count] - 1; j>= 0; --j)
            {
                if ([store_item id] == [[dataItems objectAtIndex:i] id])
                {
                    isInList = true;
                    break;
                }
            }
            if (!isInList)
            {
                [store_item setName:[[NSString stringWithFormat:NSLocalizedString(@"PREF_DISCONNECTED_MONITOR", NULL), [store_item id]] retain]];
                [dataItems addObject:store_item];
            }
        }
        
        
        
        
    }
    
    return [dataItems count];
    
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return NO;
}


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    
    if (item == nil)
    {
        return [dataItems objectAtIndex:index];
    }
    return nil;
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    if (item == nil)
        return nil;
    if ([[tableColumn identifier] isEqualToString:@"Name"])
    {
        DisplayIDAndNameCondition *idAndNameCondition = (DisplayIDAndNameCondition*)item;
        return [idAndNameCondition name];
    }
    else if ([[tableColumn identifier] isEqualToString:@"CheckBoxEnabled"])
    {
        DisplayIDAndNameCondition *idAndNameCondition = (DisplayIDAndNameCondition*)item;
        return [NSNumber numberWithBool:[idAndNameCondition enabled]];
    }
    else if ([[tableColumn identifier] isEqualToString:@"CheckBoxDisabled"])
    {
        DisplayIDAndNameCondition *idAndNameCondition = (DisplayIDAndNameCondition*)item;
        return [NSNumber numberWithBool:[idAndNameCondition disabled]];
    }
    return nil;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item  {
    if ([[tableColumn identifier] isEqualToString:@"CheckBoxEnabled"] || [[tableColumn identifier] isEqualToString:@"CheckBoxDisabled"])
    {
        DisplayIDAndNameCondition *idAndNameCondition = [dataItems objectAtIndex:[dataItems indexOfObject:item]];
        if ([[tableColumn identifier] isEqualToString:@"CheckBoxEnabled"])
        {
            [idAndNameCondition setEnabled:[object boolValue]];
            if ([idAndNameCondition enabled] && [idAndNameCondition disabled])
            {
                [idAndNameCondition setEnabled:true];
                [idAndNameCondition setDisabled:false];
            }
        }
        else
        {
            [idAndNameCondition setDisabled:[object boolValue]];
            if ([idAndNameCondition enabled] && [idAndNameCondition disabled])
            {
                [idAndNameCondition setEnabled:false];
                [idAndNameCondition setDisabled:true];
            }
        }
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *dict = [ResolutionDataSource getDictForDisplay:userDefaults display:display];
        
        NSMutableArray *archiveArray = [NSMutableArray arrayWithCapacity:[dataItems count]];
        for (DisplayIDAndNameCondition *item in dataItems) {
            if ([item enabled] || [item disabled])
            {
                NSData *encodedItem = [NSKeyedArchiver archivedDataWithRootObject:item];
                [archiveArray addObject:encodedItem];
            }
        }
        
        [dict setObject:archiveArray forKey:listToUse];
        [userDefaults setObject:dict forKey:[NSString stringWithFormat:@"%u", display]];
        [userDefaults synchronize];
        [outlineView reloadData];
    }
}


- (id) initWithDisplay:(CGDirectDisplayID)aDisplay useEnableList:(BOOL)useEnableList
{
    self = [super init];
    if (self) {
        dataItems = nil;
        if (useEnableList)
            listToUse = @"enable_ruleset";
        else
            listToUse = @"disable_ruleset";
        [self setDisplay:aDisplay];
        
    }
    return self;
}


- (oneway void) release
{
    if (dataItems != nil)
    {
        [dataItems release];
        dataItems = nil;
    }
}


@end
