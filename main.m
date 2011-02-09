//
//  main.m
//  xcodeproj
//
//  Created by Cédric Luthi on 07.02.11.
//  Copyright Cédric Luthi 2011. All rights reserved.
//

#import "xcodeproj.h"

int main(int argc, char *const *argv)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	return DDCliAppRunWithClass([Xcodeproj class]);
	[pool drain];
}
