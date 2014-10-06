@protocol NSString;

@protocol PBXBuildFile <NSObject>

- (NSString *) absolutePath;

- (NSArray *) attributes;

@end
