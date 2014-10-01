//
//  XMLPlistDecoder.h
//  xcproj
//
//  Created by Cédric Luthi on 01.10.14.
//  Copyright (c) 2014 Cédric Luthi. All rights reserved.
//

#import <Foundation/Foundation.h>

// Very rough and mostly untested XML plist decoder whose goal is to workaround http://openradar.appspot.com/18512876
// This will be useful for CocoaPods/Xcodeproj, see https://github.com/CocoaPods/Xcodeproj/issues/196 for more information.

@interface XMLPlistDecoder : NSObject

+ (id) plistWithData:(NSData *)data;

@end
