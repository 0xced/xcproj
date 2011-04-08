#import "PBXFileReference.h"
#import "PBXGroup.h"

@protocol PBXContainer <NSObject>

- (id<PBXGroup>) rootGroup;

@end
