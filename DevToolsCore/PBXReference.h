
@protocol PBXGroup;

@protocol PBXReference <NSObject>

- (NSString *) name;
- (NSString *) sourceTree;

- (NSArray *) allReferencesForGroup:(id<PBXGroup>)group; // PBXReference

@end
