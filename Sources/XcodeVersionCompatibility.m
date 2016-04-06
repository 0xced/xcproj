//
//  Created by Cédric Luthi on 06/04/16.
//  Copyright © 2016 Cédric Luthi. All rights reserved.
//

#import "XcodeVersionCompatibility.h"

#import <objc/runtime.h>

void InitializeXcodeVersionCompatibility(void)
{
	// initForBuildWithConfigurationName: did not exist before Xcode 7.3
	const char *typeEncoding = method_getTypeEncoding(class_getInstanceMethod(NSObject.class, @selector(awakeAfterUsingCoder:)));
	class_addMethod(objc_getClass("IDEBuildParameters"), @selector(initForBuildWithConfigurationName:), imp_implementationWithBlock(^(id buildParameters, NSString *configurationName) {
		[buildParameters setValue:@"build" forKey:@"buildAction"];
		[buildParameters setValue:configurationName forKey:@"configurationName"];
		return buildParameters;
	}), typeEncoding);
}
