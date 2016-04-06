//
//  Created by Cédric Luthi on 06/04/16.
//  Copyright © 2016 Cédric Luthi. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface Tests : XCTestCase

@property NSArray *xcodeURLs;

@end

@implementation Tests

- (void) run:(NSArray *)arguments expectedResult:(NSString *)expectedResult
{
	NSString *builtProductsDir = NSProcessInfo.processInfo.environment[@"BUILT_PRODUCTS_DIR"];
	NSString *projectDir = NSProcessInfo.processInfo.environment[@"PROJECT_DIR"];
	for (NSURL *xcodeURL in self.xcodeURLs)
	{
		NSTask *xcproj = [NSTask new];
		xcproj.launchPath = [builtProductsDir stringByAppendingPathComponent:@"xcproj"];
		xcproj.arguments = arguments;
		xcproj.environment = @{ @"XCPROJ_XCODE_APP_PATH": xcodeURL.path };
		xcproj.currentDirectoryPath = [projectDir stringByAppendingPathComponent:@"Sandbox"];;
		xcproj.standardOutput = [NSPipe new];
		printf("%s\n", [NSString stringWithFormat:@"env XCPROJ_XCODE_APP_PATH=%@ %@ %@", xcproj.environment[@"XCPROJ_XCODE_APP_PATH"], xcproj.launchPath, [xcproj.arguments componentsJoinedByString:@" "]].UTF8String);
		[xcproj launch];
		[xcproj waitUntilExit];
		
		NSData *outputData = [[xcproj.standardOutput fileHandleForReading] readDataToEndOfFile];
		NSString *result = [[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		printf("%s\n", result.UTF8String);
		
		XCTAssertEqual(xcproj.terminationStatus, 0);
		XCTAssertEqualObjects(result, expectedResult);
	}
}

- (void) setUp
{
	self.xcodeURLs = CFBridgingRelease(LSCopyApplicationURLsForBundleIdentifier(CFSTR("com.apple.dt.Xcode"), NULL));
	XCTAssertTrue(self.xcodeURLs.count > 0);
}

- (void) testReadBuildSetting
{
	[self run:@[ @"--target", @"Sandbox",                                 @"read-build-setting", @"COPY_PHASE_STRIP"] expectedResult:@"YES"];
	[self run:@[ @"--target", @"Sandbox", @"--configuration", @"Debug",   @"read-build-setting", @"COPY_PHASE_STRIP"] expectedResult:@"NO"];
	[self run:@[ @"--target", @"Sandbox", @"--configuration", @"Release", @"read-build-setting", @"COPY_PHASE_STRIP"] expectedResult:@"YES"];
	[self run:@[                                                          @"read-build-setting", @"COPY_PHASE_STRIP"] expectedResult:@"YES"];
	[self run:@[                          @"--configuration", @"Debug",   @"read-build-setting", @"COPY_PHASE_STRIP"] expectedResult:@"YES"];
	[self run:@[                          @"--configuration", @"Release", @"read-build-setting", @"COPY_PHASE_STRIP"] expectedResult:@"YES"];
	
	[self run:@[ @"--target", @"Sandbox", @"read-build-setting", @"CURRENT_PROJECT_VERSION"] expectedResult:@"1.2.3"];
	[self run:@[                          @"read-build-setting", @"CURRENT_PROJECT_VERSION"] expectedResult:@"1.2.3"];
}

@end
