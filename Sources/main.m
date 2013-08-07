//
//  main.m
//  xcproj
//
//  Created by Cédric Luthi on 07.02.11.
//  Copyright Cédric Luthi 2011. All rights reserved.
//

#import "Xcproj.h"

int main(int argc, char *const *argv)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	return DDCliAppRunWithClass([Xcproj class]);
	[pool drain];
}
