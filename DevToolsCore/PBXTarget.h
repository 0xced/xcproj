#import "PBXBuildPhase.h"

@protocol PBXTarget <NSObject>

- (NSString *) name;

- (NSArray *) buildConfigurations; // XCBuildConfiguration

- (id<PBXBuildPhase>) defaultFrameworksBuildPhase;
- (id<PBXBuildPhase>) defaultLinkBuildPhase;
- (id<PBXBuildPhase>) defaultSourceCodeBuildPhase;
- (id<PBXBuildPhase>) defaultResourceBuildPhase;
- (id<PBXBuildPhase>) defaultHeaderBuildPhase;

@end
