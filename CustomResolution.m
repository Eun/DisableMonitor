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

#import <Foundation/Foundation.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import "CustomResolution.h"
#import "DisplayData.h"

@implementation CustomResolution

#define DisableMagicNumber 98742

- (id)initWithDisplayID:(CGDirectDisplayID)aDisplay {
    self = [super init];
    if (self) {
        displayID = aDisplay;
        resolutions = nil;
        [self GetCustomResolutions];
    }
    return self;
}
- (oneway void)dealloc {
    if (resolutions != nil)
    {
        for (ResolutionDataItem *rdi in resolutions)
        {
            [rdi release];
        }
        [resolutions release];
        resolutions = nil;
    }
    [super dealloc];
}

- (void) GetCustomResolutions
{
    io_service_t service = IOServicePortFromCGDisplayID(displayID);
    if (service)
    {
        resolutions = [[NSMutableArray alloc] init];
        NSDictionary *deviceInfo = (NSDictionary *)IODisplayCreateInfoDictionary(service, kIODisplayOnlyPreferredName);
        NSNumber *displayVendorID = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayVendorID]];
        NSNumber *displayProductID = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductID]];
        
        NSString *filePath = [NSString  stringWithFormat:@"/System/Library/Displays/Overrides/DisplayVendorID-%x/DisplayProductID-%x", (int)[displayVendorID integerValue], (int)[displayProductID integerValue]];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
        {
            NSDictionary *displayDict = [[NSDictionary alloc] initWithContentsOfFile:filePath];
            NSArray *scaleResolutions = [displayDict objectForKey:@"scale-resolutions"];
            
            for (NSData *data in scaleResolutions)
            {
                NSData *data4 = [data subdataWithRange:NSMakeRange(0, 4)];
                int width = CFSwapInt32BigToHost(*(int*)([data4 bytes]));
                data4 = [data subdataWithRange:NSMakeRange(4, 4)];
                int height = CFSwapInt32BigToHost(*(int*)([data4 bytes]));
                data4 = [data subdataWithRange:NSMakeRange(8, 4)];
                int unknown = CFSwapInt32BigToHost(*(int*)([data4 bytes]));
                if (unknown == DisableMagicNumber)
                {
                    ResolutionDataItem *rdi = [[ResolutionDataItem alloc] init];
                    [rdi setWidth:width];
                    [rdi setHeight:height];
                    [resolutions addObject:rdi];
                }
            }
            [displayDict release];
        }
        [deviceInfo release];
    }
}


- (BOOL)MoveFileToLocation:(NSString *)src dst:(NSString*)dst
{
    // Create authorization reference
    OSStatus status;
    AuthorizationRef authorizationRef;
    
    // AuthorizationCreate and pass NULL as the initial
    // AuthorizationRights set so that the AuthorizationRef gets created
    // successfully, and then later call AuthorizationCopyRights to
    // determine or extend the allowable rights.
    // http://developer.apple.com/qa/qa2001/qa1172.html
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    if (status != errAuthorizationSuccess)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText:[NSString stringWithFormat: NSLocalizedString(@"ERROR_AUTH",NULL),status ]];
        [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"ALERT_ERROR", NULL)];
        [alert runModal];
        [alert release];
        return NO;
    }
    
    // kAuthorizationRightExecute == "system.privilege.admin"
    AuthorizationItem right = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights rights = {1, &right};
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
    kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    // Call AuthorizationCopyRights to determine or extend the allowable rights.
    status = AuthorizationCopyRights(authorizationRef, &rights, NULL, flags, NULL);
    if (status != errAuthorizationSuccess)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText:[NSString stringWithFormat: NSLocalizedString(@"ERROR_AUTH2",NULL),status ]];
        [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"ALERT_ERROR", NULL)];
        [alert runModal];
        [alert release];
        return NO;
    }
    
    char *tool = "/bin/mv";
    char *args[] = {"-f" ,(char *)[src UTF8String], (char *)[dst UTF8String], NULL};
    FILE *pipe = NULL;
    
    status = AuthorizationExecuteWithPrivileges(authorizationRef, tool, kAuthorizationFlagDefaults, args, &pipe);
    if (status != errAuthorizationSuccess)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText:[NSString stringWithFormat: NSLocalizedString(@"ERROR_AUTH3", NULL),status ]];
        [alert addButtonWithTitle:NSLocalizedString(@"ALERT_OK", NULL)];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"ALERT_ERROR", NULL)];
        [alert runModal];
        [alert release];
        return NO;
    }
    
    // The only way to guarantee that a credential acquired when you
    // request a right is not shared with other authorization instances is
    // to destroy the credential.  To do so, call the AuthorizationFree
    // function with the flag kAuthorizationFlagDestroyRights.
    // http://developer.apple.com/documentation/Security/Conceptual/authorization_concepts/02authconcepts/chapter_2_section_7.html
    status = AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
    return YES;
}

- (bool) addCustomResolution:(ResolutionDataItem*)item
{
    if ([self isCustomItem:item])
        return false;
    
    io_service_t service = IOServicePortFromCGDisplayID(displayID);
    if (service)
    {
        NSDictionary *deviceInfo = (NSDictionary *)IODisplayCreateInfoDictionary(service, kIODisplayOnlyPreferredName);
        NSNumber *displayVendorID = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayVendorID]];
        NSNumber *displayProductID = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductID]];
        
        NSString *filePath = [NSString  stringWithFormat:@"/System/Library/Displays/Overrides/DisplayVendorID-%x/DisplayProductID-%x", (int)[displayVendorID integerValue], (int)[displayProductID integerValue]];
        
        NSMutableDictionary *displayDict;
        NSMutableArray *scaleResolutions;
  
        bool bNewFile = ![[NSFileManager defaultManager] fileExistsAtPath:filePath];
        
        if (!bNewFile)
        {
            displayDict = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
            scaleResolutions = [displayDict objectForKey:@"scale-resolutions"];
            
            bool bItemExists = false;
            for (NSData *data in scaleResolutions)
            {
                NSData *data4 = [data subdataWithRange:NSMakeRange(0, 4)];
                int width = CFSwapInt32BigToHost(*(int*)([data4 bytes]));
                data4 = [data subdataWithRange:NSMakeRange(4, 4)];
                int height = CFSwapInt32BigToHost(*(int*)([data4 bytes]));
                if (width == [item mode].width && height == [item mode].height)
                {
                    bItemExists = true;
                    break;
                }
                
            }
            
            if (bItemExists == true)
            {
                [displayDict release];
                [deviceInfo release];
                return false;
            }
           
        }
        else
        {
            displayDict = [[NSMutableDictionary alloc] init];
            scaleResolutions = [[NSMutableArray alloc] init];
        }
        
        NSMutableData *md = [[NSMutableData alloc] initWithCapacity:12];
        
        NSInteger width = CFSwapInt32HostToBig([item mode].width);
        NSInteger height = CFSwapInt32HostToBig([item mode].height);
        NSInteger magical = CFSwapInt32HostToBig(DisableMagicNumber);
        
        [md appendBytes:&width length:4];
        [md appendBytes:&height length:4];
        [md appendBytes:&magical length:4];
        
        [scaleResolutions addObject:[NSData dataWithData:md]];
        [md release];
        
        if (bNewFile)
        {
            [displayDict setObject: scaleResolutions forKey:@"scale-resolutions"];
            [scaleResolutions release];
        }
        
        NSString *tmpFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%0.f", [NSDate timeIntervalSinceReferenceDate] * 1000.0]];
        
        if ([displayDict writeToFile:tmpFile atomically:YES] == false)
        {
            [displayDict release];
            [deviceInfo release];
            return false;
        }
        
        if ([self MoveFileToLocation:tmpFile dst:filePath] == false)
        {
            [displayDict release];
            [deviceInfo release];
            return false;
        }

        
        [displayDict release];
        
        [deviceInfo release];
    }

    
    if (resolutions == nil)
    {
        resolutions = [[NSMutableArray alloc] init];
    }
    ResolutionDataItem *rdi = [[ResolutionDataItem alloc] init];
    [rdi setWidth :[item mode].width];
    [rdi setHeight:[item mode].height];
    [resolutions addObject:rdi];
    return true;
}


- (bool) removeCustomResolution:(ResolutionDataItem*)item
{
    if (![self isCustomItem:item])
        return false;
    
    io_service_t service = IOServicePortFromCGDisplayID(displayID);
    if (service)
    {
        NSDictionary *deviceInfo = (NSDictionary *)IODisplayCreateInfoDictionary(service, kIODisplayOnlyPreferredName);
        NSNumber *displayVendorID = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayVendorID]];
        NSNumber *displayProductID = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductID]];
        
        NSString *filePath = [NSString  stringWithFormat:@"/System/Library/Displays/Overrides/DisplayVendorID-%x/DisplayProductID-%x", (int)[displayVendorID integerValue], (int)[displayProductID integerValue]];
        
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
        {
            NSMutableDictionary *displayDict = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
            NSMutableArray *scaleResolutions = [displayDict objectForKey:@"scale-resolutions"];
            
            bool bItemExists = false;
            for (int i = 0; i < [scaleResolutions count]; i++)
            {
                NSData *data = [scaleResolutions objectAtIndex:i];
                NSData *data4 = [data subdataWithRange:NSMakeRange(0, 4)];
                int width = CFSwapInt32BigToHost(*(int*)([data4 bytes]));
                data4 = [data subdataWithRange:NSMakeRange(4, 4)];
                int height = CFSwapInt32BigToHost(*(int*)([data4 bytes]));
                if (width == [item mode].width && height == [item mode].height)
                {
                    bItemExists = true;
                    [scaleResolutions removeObjectAtIndex:i];
                    break;
                }
            }
            
            if (bItemExists == true)
            {
                
                
                NSString *tmpFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%0.f", [NSDate timeIntervalSinceReferenceDate] * 1000.0]];
                
                if ([displayDict writeToFile:tmpFile atomically:YES] == false)
                {
                    [displayDict release];
                    [deviceInfo release];
                    return false;
                }
                
                
                if ([self MoveFileToLocation:tmpFile dst:filePath] == false)
                {
                    [displayDict release];
                    [deviceInfo release];
                    return false;
                }
            }
            [displayDict release];

        }
        [deviceInfo release];
    }
    
    
    if (resolutions != nil)
    {
        for (int i = 0; i < [resolutions count]; i++)
        {
            ResolutionDataItem *rdi = [resolutions objectAtIndex:i];
            if ([rdi mode].width == [item mode].width && [rdi mode].height == [item mode].height)
            {
                [resolutions removeObjectAtIndex:i];
                [rdi release];
                break;
            }
        }
    }
    return true;
}


- (bool) isCustomItem:(ResolutionDataItem*)item
{
    if (resolutions != nil)
    {
        for (ResolutionDataItem *rdi in resolutions)
        {
            if ([rdi mode].width == [item mode].width && [rdi mode].height == [item mode].height)
                return true;
        }
    }
    return false;
}



@end
