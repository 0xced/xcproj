About
=====

**xcproj** is a command line tool for manipulating Xcode project files.

***It is at very early stage of development.***

Limitations
===========

* **xcproj** relies on the DevToolsCore private framework. Although great care has been taken, it might stop working anytime.

* The **xcproj** binary is bound to the Xcode version that compiled it. If you delete, move or rename the Xcode version that compiled the binary, **xcproj** will fail with the following error: `The DevToolsCore framework failed to load: DevToolsCore.framework not found`