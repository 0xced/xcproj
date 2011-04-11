#import "PBXFileReference.h"

@protocol XCBuildConfiguration <NSObject>

- (void) setBaseConfigurationReference:(id<PBXFileReference>)reference;
- (id<PBXFileReference>) baseConfigurationReference;

@end
