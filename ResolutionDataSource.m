//
//  ResolutionDataSource.m
//  DisableMonitor
//
//  Created by salzmann on 18.07.14.
//
//

#import "ResolutionDataSource.h"
#import "ResolutionDataItem.h"

#import "DisplayData.h"

@implementation ResolutionDataSource
@synthesize display;
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item != nil)
        return 0;
    int numberOfDisplayModes;
    CGSGetNumberOfDisplayModes(display, &numberOfDisplayModes);

    if (dataItems != nil)
    {
       [dataItems release];
        dataItems = nil;
    }
    
    
    if (numberOfDisplayModes > 0)
    {
        NSMutableArray *items = [[NSMutableArray alloc] init];
        for (int j = 0; j < numberOfDisplayModes; j++) {
            
            CGSDisplayMode mode;
            CGSGetDisplayModeDescriptionOfLength(display, j, &mode, sizeof(mode));
            [items addObject: [[ResolutionDataItem alloc] initWithMode:mode]];
        }
        [self LoadData:items];
        
        dataItems = [[items sortedArrayUsingComparator:^NSComparisonResult(ResolutionDataItem* a, ResolutionDataItem* b) {
            CGSDisplayMode mymode = [a mode];
            CGSDisplayMode othermode = [b mode];
            
            if (![a visible] && ![b visible])
                return NSOrderedSame;
            else if ([a visible] && ![b visible])
                return NSOrderedAscending;
            else if (![a visible] && [b visible])
                return NSOrderedDescending;
            
            if (mymode.width > othermode.width)
                return NSOrderedAscending;
            else if (mymode.width < othermode.width)
                return NSOrderedDescending;
            else
                return NSOrderedSame;
        }] mutableCopy];
        [items release];
    }
    return numberOfDisplayModes;
}


NSArray *sortedArray;



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
    if ([[tableColumn identifier] isEqualToString:@"Name"])
    {
        CGSDisplayMode mode = [(ResolutionDataItem*)item mode];
        size_t w = mode.width;
        size_t h = mode.height;
        size_t d = [self bitDepth:display];
        // size_t d = mode.depth;
        int r = (int)mode.freq;
        
        int gcd = [ResolutionDataItem gcd:w height:h];
        
        
        int fontSize = [NSFont systemFontSize];
        
        NSMutableString *res = [NSMutableString stringWithFormat:@"%lux%lux%lu@%d ", w, h, d, r];
        int lres = [res length];
        [res appendFormat:@"[%d:%d]", (int)w/gcd, (int)h/gcd];
        int lrat = [res length] - lres;
        
        NSMutableAttributedString *titleText = [[NSMutableAttributedString alloc] initWithString:res];
        [titleText addAttributes:[NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:fontSize] forKey:NSFontAttributeName] range:NSMakeRange(0, lres)];
        
        
        [titleText addAttributes:[NSDictionary dictionaryWithObject:[NSFont boldSystemFontOfSize:fontSize*.7] forKey:NSFontAttributeName] range:NSMakeRange(lres, lrat)];
        [titleText addAttribute:NSBaselineOffsetAttributeName value:[NSNumber numberWithFloat:fontSize/(fontSize*.7)] range:NSMakeRange(lres, lrat)];
        
        return titleText;
        
        
        
        //return [NSString stringWithFormat:@"%lux%lux%lu@%d", w, h, d, r];
    }
    else if ([[tableColumn identifier] isEqualToString:@"CheckBox"])
    {
        return [NSNumber numberWithBool:[item visible]];
    }
    return nil;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item  {
    if ([[tableColumn identifier] isEqualToString:@"CheckBox"])
    {
        [[dataItems objectAtIndex:[dataItems indexOfObject:item]] setVisible:[object boolValue]];
        [self SaveData];
        [outlineView reloadData];
    }
}

-(size_t) bitDepth:(CGDirectDisplayID) displayId
{
    size_t depth = 0;
    char *buffer = (char*)calloc(33, sizeof(char*));
    CGSGetDisplayPixelEncodingOfLength(displayId, buffer, 32);
    CFStringRef pixelEncoding = (CFStringRef)[NSString stringWithFormat:@"%s", buffer];
    
    // my numerical representation for kIO16BitFloatPixels and kIO32bitFloatPixels
    // are made up and possibly non-sensical
    if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(kIO32BitFloatPixels), kCFCompareCaseInsensitive)) {
        depth = 96;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(kIO64BitDirectPixels), kCFCompareCaseInsensitive)) {
        depth = 64;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(kIO16BitFloatPixels), kCFCompareCaseInsensitive)) {
        depth = 48;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(IO32BitDirectPixels), kCFCompareCaseInsensitive)) {
        depth = 32;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(kIO30BitDirectPixels), kCFCompareCaseInsensitive)) {
        depth = 30;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(IO16BitDirectPixels), kCFCompareCaseInsensitive)) {
        depth = 16;
    } else if (kCFCompareEqualTo == CFStringCompare(pixelEncoding, CFSTR(IO8BitIndexedPixels), kCFCompareCaseInsensitive)) {
        depth = 8;
    }
    
    free(buffer);
    return depth;
}

- (id) initWithDisplay:(CGDirectDisplayID)aDisplay
{
    self = [super init];
    if (self) {
        dataItems = nil;
        [self setDisplay:aDisplay];
    }
    return self;
}

- (void) SaveData
{
    if (dataItems != nil)
    {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        
        // encode data
        NSMutableArray *archiveArray = [NSMutableArray arrayWithCapacity:[dataItems count]];
        for (ResolutionDataItem *item in dataItems) {
            NSData *encodedItem = [NSKeyedArchiver archivedDataWithRootObject:item];
            [archiveArray addObject:encodedItem];
        }
        [userDefaults setObject:archiveArray forKey:[NSString stringWithFormat:@"%u", display]];
        [userDefaults synchronize];
    }
}

- (void) LoadData:(NSMutableArray*)system_items
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *items = [userDefaults objectForKey:[NSString stringWithFormat:@"%u", display]];
    if (items != nil)
    {
        for (int i = [items count] - 1; i>= 0; --i)
        {
            NSData *encodedItem = [items objectAtIndex:i];
            ResolutionDataItem *item =[NSKeyedUnarchiver unarchiveObjectWithData:encodedItem];
            for (int j = [system_items count] - 1; j>= 0; --j)
            {
                ResolutionDataItem *sysitem = system_items[j];
                
                if (sysitem.mode.width == item.width && sysitem.mode.height == item.height && sysitem.mode.depth == item.depth && sysitem.mode.freq == item.freq)
                {
                    [sysitem setVisible:[item visible]];
                    [sysitem setCustom:[item custom]];
                    break;
                }
            }
        }
    }
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
