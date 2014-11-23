//
//  NSColor+Hex.h
//  EncounterConnect
//
//  Created by Kevin Bradley on 9/19/13.
//  Copyright (c) 2013 nito. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSColor (Hex)
+ (NSColor *)lightBlueAlternate;
+ (NSColor *)lightBlueColor;
+ (NSColor *)colorFromHex:(NSString *)s;
- (NSString *)hexValue;
+ (NSColor *)sourceListLightColor;
@end
