//
//  XMLPlistDecoder.m
//  xcproj
//
//  Created by Cédric Luthi on 01.10.14.
//  Copyright (c) 2014 Cédric Luthi. All rights reserved.
//

#import "XMLPlistDecoder.h"

static id ObjectFromElement(NSXMLElement *element);

static NSArray * ArrayFromElement(NSXMLElement *element)
{
	NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[element childCount]];
	for (NSXMLElement *child in [element children])
	{
		[array addObject:ObjectFromElement(child)];
	}
	return [array copy];
}

static NSDictionary * DictionaryFromElement(NSXMLElement *element)
{
	NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:[element childCount] / 2];
	NSString *key;
	for (NSXMLElement *child in [element children])
	{
		if ([child.name isEqualToString:@"key"])
			key = [child stringValue];
		else
			dictionary[key] = ObjectFromElement(child);
	}
	return [dictionary copy];
}

static NSString * StringFromElement(NSXMLElement *element)
{
	return [element stringValue] ?: @"";
}

static NSData * DataFromElement(NSXMLElement *element)
{
	return [[NSData alloc] initWithBase64Encoding:[element stringValue]];
}

static NSDate * DateFromElement(NSXMLElement *element)
{
	static NSDateFormatter *dateFormatter;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
		[dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
	});
	
	return [dateFormatter dateFromString:[element stringValue]] ?: [NSDate dateWithTimeIntervalSince1970:0];
}

static NSNumber * NumberFromElement(NSXMLElement *element)
{
	NSString *stringValue = [element stringValue];
	if ([element.name isEqualToString:@"integer"])
		return [NSNumber numberWithInteger:[stringValue integerValue]];
	else
		return [NSNumber numberWithDouble:[stringValue doubleValue]];
}

static id ObjectFromElement(NSXMLElement *element)
{
	// See CFXMLPlistTags in CFPropertyList.c
	if ([element.name isEqualToString:@"array"])
		return ArrayFromElement(element);
	else if ([element.name isEqualToString:@"dict"])
		return DictionaryFromElement(element);
	else if ([element.name isEqualToString:@"string"])
		return StringFromElement(element);
	else if ([element.name isEqualToString:@"data"])
		return DataFromElement(element);
	else if ([element.name isEqualToString:@"date"])
		return DateFromElement(element);
	else if ([element.name isEqualToString:@"real"] || [element.name isEqualToString:@"integer"])
		return NumberFromElement(element);
	else if ([element.name isEqualToString:@"true"])
		return @YES;
	else if ([element.name isEqualToString:@"false"])
		return @NO;
	else
		return [NSNull null];
}

@implementation XMLPlistDecoder

+ (id) plistWithData:(NSData *)data
{
	NSXMLDocument *document = [[NSXMLDocument alloc] initWithData:data options:0 error:NULL];
	if (!document)
		return nil;
	
	NSXMLElement *plistElement = [document rootElement];
	if (![plistElement.name isEqualToString:@"plist"] || [plistElement childCount] != 1)
		return nil;
	
	return ObjectFromElement((NSXMLElement *)[plistElement childAtIndex:0]);
}

@end
