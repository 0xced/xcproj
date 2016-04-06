//
//  Created by Cédric Luthi on 06/04/16.
//  Copyright © 2016 Cédric Luthi. All rights reserved.
//

#import "XcodeVersionCompatibility.h"

#import <objc/runtime.h>

@interface NSObject (PBXProject)
- (id) expandedValueForString:(NSString *)string forBuildParameters:(id)buildParameters withFallbackConfigurationName:(NSString *)fallbackConfigurationName;
@end

void InitializeXcodeVersionCompatibility(void)
{
	// initForBuildWithConfigurationName: did not exist before Xcode 7.3
	class_addMethod(objc_getClass("IDEBuildParameters"), @selector(initForBuildWithConfigurationName:), imp_implementationWithBlock(^(id buildParameters, NSString *configurationName) {
		[buildParameters setValue:@"build" forKey:@"buildAction"];
		[buildParameters setValue:configurationName forKey:@"configurationName"];
		return buildParameters;
	}), method_getTypeEncoding(class_getInstanceMethod(NSObject.class, @selector(awakeAfterUsingCoder:))));
	
	// expandedValueForString:forBuildParameters: did not exist before Xcode 7
	class_addMethod(objc_getClass("PBXProject"), @selector(expandedValueForString:forBuildParameters:), imp_implementationWithBlock(^(id project, NSString *string, id buildParameters) {
		return [project expandedValueForString:string forBuildParameters:buildParameters withFallbackConfigurationName:nil];
	}), method_getTypeEncoding(class_getInstanceMethod(NSString.class, @selector(stringByReplacingOccurrencesOfString:withString:))));
}
