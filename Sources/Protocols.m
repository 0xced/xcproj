#import <DevToolsCore/DevToolsCore.h>

// For the compiler to "embed" the protocols in the binary

void protocols()
{
	(void)@protocol(PBXBuildFile);
	(void)@protocol(PBXBuildPhase);
	(void)@protocol(PBXContainer);
	(void)@protocol(PBXFileReference);
	(void)@protocol(PBXGroup);
	(void)@protocol(PBXProject);
	(void)@protocol(PBXReference);
	(void)@protocol(PBXTarget);
	(void)@protocol(XCBuildConfiguration);
	(void)@protocol(XCConfigurationList);
}
