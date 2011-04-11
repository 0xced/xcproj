#import "PBXGroup.h"
#import "PBXFileReference.h"

@protocol PBXContainer <NSObject>

- (id<PBXGroup>) rootGroup;

- (id<PBXFileReference>) fileReferenceForPath:(NSString *)path;

@end
