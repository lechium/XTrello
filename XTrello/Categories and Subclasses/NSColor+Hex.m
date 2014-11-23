//
//  NSColor+Hex.m
//  EncounterConnect
//
//  Created by Kevin Bradley on 9/19/13.
//  Copyright (c) 2013 nito. All rights reserved.
//

#import "NSColor+Hex.h"

@implementation NSColor (Hex)

+ (NSColor *)lightBlueAlternate
{
    return [NSColor colorFromHex:@"149CEA"];
}

+(NSColor *)lightBlueColor
{
    return [NSColor colorFromHex:@"89bce9"];
}

+ (NSColor *)colorFromHex:(NSString *)s
{
	NSScanner *scan = [NSScanner scannerWithString:[s substringToIndex:2]];
	unsigned int r = 0, g = 0, b = 0;
	[scan scanHexInt:&r];
	scan = [NSScanner scannerWithString:[[s substringFromIndex:2] substringToIndex:2]];
	[scan scanHexInt:&g];
	scan = [NSScanner scannerWithString:[s substringFromIndex:4]];
	[scan scanHexInt:&b];
	
	
	return [NSColor colorWithCalibratedRed:(float)r/255.0 green:(float)g/255.0 blue:(float)b/255.0 alpha:1.0];
}

- (NSString *)hexValue
{
	CGFloat red, green, blue;
    [[self colorUsingColorSpaceName: NSCalibratedRGBColorSpace]
	 getRed: &red green: &green blue: &blue alpha: nil];
	
	NSString *occs = [NSString stringWithFormat: @"%02X%02X%02X", (unsigned)(red*255.0),
					  (unsigned)(green*255.0), (unsigned)(blue*255.0)];
	
	
	return occs;
}

+ (NSColor *)sourceListLightColor
{
     return [NSColor colorWithCatalogName:@"System" colorName:@"_sourceListBackgroundColor"];
}

@end
