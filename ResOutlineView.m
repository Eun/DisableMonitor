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

-(void)outlineView:(NSOutlineView *)outlineView willDisplayOutlineCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSUInteger rowNo = [outlineView rowForItem:item];
    
    NSColor *backgroundColor;
    /*if ( [[outlineView selectedRowIndexes] containsIndex:rowNo] ) {
     backgroundColor = // Highlighted color;
     }
     else {*/
    backgroundColor = [NSColor redColor];
    //}
    
    [cell setBackgroundColor: backgroundColor];
}

-(void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    
    NSUInteger rowNo = [outlineView rowForItem:item];
    
    NSColor *backgroundColor;
    /*if ( [[outlineView selectedRowIndexes] containsIndex:rowNo] ) {
        backgroundColor = // Highlighted color;
    }
    else {*/
        backgroundColor = [NSColor brownColor];
    //}
    
    [cell setBackgroundColor: backgroundColor];
}

@end
