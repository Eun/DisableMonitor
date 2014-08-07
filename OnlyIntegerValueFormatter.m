//
//  OnlyIntegerValueFormatter.m
//  DisableMonitor
//
//  Created by salzmann on 30.07.14.
//
//

#import "OnlyIntegerValueFormatter.h"

@implementation OnlyIntegerValueFormatter

- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**)newString errorDescription:(NSString**)error
{
    if([partialString length] == 0) {
        return YES;
    }
    
    NSScanner* scanner = [NSScanner scannerWithString:partialString];
    
    if(!([scanner scanInt:0] && [scanner isAtEnd])) {
        NSBeep();
        return NO;
    }
    
    return YES;
}

@end
