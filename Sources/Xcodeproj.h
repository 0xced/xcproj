//
//  Xcodeproj.h
//  xcodeproj
//
//  Created by Cédric Luthi on 07.02.11.
//  Copyright Cédric Luthi 2011. All rights reserved.
//

#import "DDCommandLineInterface.h"

#import <DevToolsCore/DevToolsCore.h>

@interface Xcodeproj : NSObject <DDCliApplicationDelegate>
{
	// Options
	id<PBXProject> project;
	NSString *targetName;
	BOOL help;
	// Actions
	BOOL listTargets;
	BOOL developTest;
	
	id<PBXTarget> target;
}

- (void) printTargets;
- (void) printBuildPhases;

- (BOOL) addGroup:(NSString *)groupName beforeGroup:(NSString *)otherGroupName;
- (BOOL) addGroup:(NSString *)groupName inGroup:(NSString *)otherGroupName;
- (BOOL) addFileAtPath:(NSString *)filePath inGroup:(NSString *)groupName;

@end
