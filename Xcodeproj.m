//
//  Xcodeproj.m
//  xcodeproj
//
//  Created by CŽdric Luthi on 07.02.11.
//  Copyright CŽdric Luthi 2011. All rights reserved.
//

#import "Xcodeproj.h"

@implementation Xcodeproj

- (void) application:(DDCliApplication *)app willParseOptions:(DDGetoptLongParser *)optionsParser
{
	DDGetoptOption optionTable[] = 
	{
		// Long      Short  Argument options
		{@"output",  'o',   DDGetoptRequiredArgument},
		{@"help",    'h',   DDGetoptNoArgument},
		{nil,         0,    0},
	};
	[optionsParser addOptionsFromTable:optionTable];
}

- (int) application:(DDCliApplication *)app runWithArguments:(NSArray *)arguments
{
	ddprintf(@"Output: %@, help: %d\n", _output, _help);
	ddprintf(@"Arguments: %@\n", arguments);
	return EXIT_SUCCESS;
}

@end
