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
#include <stdio.h>
#include <libgen.h>
#include <ApplicationServices/ApplicationServices.h>
#include <IOKit/graphics/IOGraphicsLib.h>

#ifdef __cplusplus
extern "C" {
#endif
    // for old macs?
    //extern CGError CGConfigureDisplayEnabled(CGDisplayConfigRef, CGDirectDisplayID, bool);
    
    
    extern CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef, CGDirectDisplayID, bool);

#ifdef __cplusplus
}
#endif

// GLFW 3.0 START
//========================================================================
// GLFW 3.0 OS X - www.glfw.org
//------------------------------------------------------------------------
// Copyright (c) 2002-2006 Marcus Geelnard
// Copyright (c) 2006-2010 Camilla Berglund <elmindreda@elmindreda.org>
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would
//    be appreciated but is not required.
//
// 2. Altered source versions must be plainly marked as such, and must not
//    be misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source
//    distribution.
//
//========================================================================
io_service_t IOServicePortFromCGDisplayID(CGDirectDisplayID displayID)
{
    io_iterator_t iter;
    io_service_t serv, servicePort = 0;
    
    CFMutableDictionaryRef matching = IOServiceMatching("IODisplayConnect");
    
    // releases matching for us
    kern_return_t err = IOServiceGetMatchingServices(kIOMasterPortDefault,
                             matching,
                             &iter);
    if (err)
    {
        return 0;
    }
    
    while ((serv = IOIteratorNext(iter)) != 0)
    {
        CFDictionaryRef info;
        CFIndex vendorID, productID;
        CFNumberRef vendorIDRef, productIDRef;
        Boolean success;
        
        info = IODisplayCreateInfoDictionary(serv,
                             kIODisplayOnlyPreferredName);
        
        vendorIDRef = CFDictionaryGetValue(info,
                           CFSTR(kDisplayVendorID));
        productIDRef = CFDictionaryGetValue(info,
                            CFSTR(kDisplayProductID));
        
        success = CFNumberGetValue(vendorIDRef, kCFNumberCFIndexType,
                                   &vendorID);
        success &= CFNumberGetValue(productIDRef, kCFNumberCFIndexType,
                                    &productID);

        if (!success)
        {
            CFRelease(info);
            continue;
        }
        
        if (CGDisplayVendorNumber(displayID) != vendorID ||
            CGDisplayModelNumber(displayID) != productID)
        {
            CFRelease(info);
            continue;
        }
        
        // we're a match
        servicePort = serv;
        CFRelease(info);
        break;
    }
    
    IOObjectRelease(iter);
    return servicePort;
}

// Get the name of the specified display
//
char* getDisplayName(CGDirectDisplayID displayID)
{
    char* name;
    CFDictionaryRef info, names;
    CFStringRef value;
    CFIndex size;
    
    io_service_t serv = IOServicePortFromCGDisplayID(displayID);
    if (!serv)
    {
        return strdup("Unknown");
    }
    
    info = IODisplayCreateInfoDictionary(serv,
                         kIODisplayOnlyPreferredName);
    
    IOObjectRelease(serv);
    
    names = CFDictionaryGetValue(info, CFSTR(kDisplayProductName));
    
    if (!names || !CFDictionaryGetValueIfPresent(names, CFSTR("en_US"),
                             (const void**) &value))
    {
        //_glfwInputError(GLFW_PLATFORM_ERROR, "Failed to retrieve display name");
        CFRelease(info);
        return strdup("Unknown");
    }
    
    size = CFStringGetMaximumSizeForEncoding(CFStringGetLength(value),
                         kCFStringEncodingUTF8);
    name = calloc(size + 1, sizeof(char));
    CFStringGetCString(value, name, size, kCFStringEncodingUTF8);
    
    CFRelease(info);
    
    return name;
}
// GLFW 3.0 END

int main(int argc, const char * argv[])
{
    
    if (argc < 2)
    {
        CGDirectDisplayID displays[0x10];
        uint32_t nDisplays;
        CGGetOnlineDisplayList(0x10, displays, &nDisplays);
        
        printf("DisableMonitor 1.1 - http://github.com/Eun/DisableMonitor\n\nusage: %s <display id>\n\n", basename((char*)argv[0]));
        
        printf("Name       | Display ID | Metrics   | Main Display? | Active?\n");
        if (nDisplays > 0)
        {
            for (int i = 0; i < nDisplays; i++)
            {
                char *name = getDisplayName(displays[i]);
                if (strlen(name) > 10)
                    name[9] = 0;
                printf("%-10s | %10d | %4dx%-4d | %-13s | %-s\n", name, displays[i], (int)CGDisplayPixelsWide(displays[i]), (int)CGDisplayPixelsHigh(displays[i]), CGDisplayIsMain(displays[i]) ? "Yes" : "No", CGDisplayIsActive(displays[i]) ? "Yes" : "No");
            }
        }
        else
        {
            printf("Could not detect displays!\n");
        }
       
        return 0;
    }
    else
    {
        CGError err;
        CGDisplayConfigRef config;

        CGDirectDisplayID display;

        if (!strncmp(argv[1], "0", strlen(argv[1])))
        {
            display = CGMainDisplayID();
        }
        else
        {
            display = atoi(argv[1]);
        }

        err = CGBeginDisplayConfiguration (&config);
        if (err != 0)
        {
            printf("Error in CGBeginDisplayConfiguration: %d\n", err);
            return err;
        }
        err = CGSConfigureDisplayEnabled(config, display, !CGDisplayIsActive(display));
        if (err != 0)
        {
            printf("Error in CGSConfigureDisplayEnabled: %d\n", err);
            return err;
        }
        err = CGCompleteDisplayConfiguration(config, kCGConfigurePermanently);
        if (err != 0)
        {
            printf("Error in CGCompleteDisplayConfiguration: %d\n", err);
            return err;
        }
    }
        
    return 0;
}

