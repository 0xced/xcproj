#import "PBXFileReference.h"

@protocol XCBuildConfiguration <NSObject>

+ (BOOL) fileReference:(id<PBXFileReference>)reference isValidBaseConfigurationFile:(NSError **)error;

- (void) setBaseConfigurationReference:(id<PBXFileReference>)reference;
- (id<PBXFileReference>) baseConfigurationReference;

@end
