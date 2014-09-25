DisableMonitor
==============
Adds the missing feature to disable a monitor on your Mac!

Easily disable, enable or change the resolution of a monitor! 


![](https://raw.githubusercontent.com/Eun/DisableMonitor/res/screenshot1.png)

Console Usage
============
You can use DisableMonitor with the console.  
Following switches are available:
```
-list           Displays a list of monitors that were detected
-enable <id>    Enables a Monitor with the matching id 
-e <id>
-disable <id>   Disables a Monitor with the matching id
-d <id>
```

Example Usage:
```
$ /Applications/DisableMonitor.app/Contents/MacOS/DisableMonitor -list
 ID         Name
----------- -----------------
 188823026  SyncMaster (1)
 188834480  SyncMaster (2)
----------- -----------------
$ /Applications/DisableMonitor.app/Contents/MacOS/DisableMonitor -disable 188834480
```

(More switches might be coming)

Changelog
=========
1.7:
* Added Updater
* Added Quit Menu (Alternative Menu)
* Added Start Screensaver Menu (Alternative Menu)
* Added console usage (Issue #8)
* Added About Dialog

1.6:
* Added Icons
* Added Lock Screens
* Fixed Issues #5 & #6

1.5:
* Minor Bugfixes

1.4:
* Manage Resolutions
+ Ratio

1.3:
* Support for 10.6

1.2:
* Move windows from disabled monitor to an active one

1.1: 
* Resolution can now be changed!
* Bugfixes
* improved stability
* added German language
