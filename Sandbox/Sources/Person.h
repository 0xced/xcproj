//
//  Person.h
//  Sandbox
//
//  Created by Cédric Luthi on 08.08.13.
//
//

#import <Foundation/Foundation.h>

@interface Person : NSObject

@property (copy) NSString *firstName;
@property (copy) NSString *lastName;
@property (strong) NSDate *birthdate;

@end
