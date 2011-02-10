#import "PBXBuildPhase.h"

@protocol PBXTarget <NSObject>

@required
- (id<PBXBuildPhase>) defaultFrameworksBuildPhase;
- (id<PBXBuildPhase>) defaultLinkBuildPhase;
- (id<PBXBuildPhase>) defaultSourceCodeBuildPhase;
- (id<PBXBuildPhase>) defaultResourceBuildPhase;
- (id<PBXBuildPhase>) defaultHeaderBuildPhase;

@optional
- (id) PBXBuildPhase$defaultFrameworksBuildPhase;
- (id) PBXBuildPhase$defaultLinkBuildPhase;
- (id) PBXBuildPhase$defaultSourceCodeBuildPhase;
- (id) PBXBuildPhase$defaultResourceBuildPhase;
- (id) PBXBuildPhase$defaultHeaderBuildPhase;

@end
