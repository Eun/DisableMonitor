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

#ifdef __cplusplus
extern "C" {
#endif
    // for old macs?
    //extern CGError CGConfigureDisplayEnabled(CGDisplayConfigRef, CGDirectDisplayID, bool);
    
    
    extern CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef, CGDirectDisplayID, bool);

#ifdef __cplusplus
}
#endif

int main(int argc, const char * argv[])
{
    
    if (argc < 2)
    {
        CGDirectDisplayID displays[0x10];
        uint32_t nDisplays;
        CGGetOnlineDisplayList(0x10, displays, &nDisplays);
        
        printf("DisableMonitor - http://github.com/Eun/DisableMonitor\n\nusage: %s <display id>\n\n", basename((char*)argv[0]));
        
        printf("Display ID | Metrics   | Main Display? | Active?\n");
        if (nDisplays > 0)
        {
            for (int i = 0; i < nDisplays; i++)
            {
                printf("%10d | %4dx%-4d | %-13s | %-s\n", displays[i], (int)CGDisplayPixelsWide(displays[i]), (int)CGDisplayPixelsHigh(displays[i]), CGDisplayIsMain(displays[i]) ? "Yes" : "No", CGDisplayIsActive(displays[i]) ? "Yes" : "No");
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

