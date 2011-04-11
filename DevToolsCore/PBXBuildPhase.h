#import "PBXFileReference.h"

@protocol PBXBuildPhase <NSObject>

+ (id<PBXBuildPhase>) buildPhase;

- (NSArray *) buildFiles; // PBXBuildFile

- (BOOL) addReference:(id<PBXFileReference>)reference;
- (BOOL) containsFileReferenceIdenticalTo:(id<PBXFileReference>)reference;

@end
