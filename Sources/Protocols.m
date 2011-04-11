#import <DevToolsCore/DevToolsCore.h>

// For the compiler to "embed" the protocols in the binary

static void protocols()
{
	@protocol(PBXBuildFile);
	@protocol(PBXBuildPhase);
	@protocol(PBXContainer);
	@protocol(PBXFileReference);
	@protocol(PBXGroup);
	@protocol(PBXProject);
	@protocol(PBXReference);
	@protocol(PBXTarget);
	@protocol(XCBuildConfiguration);
}
