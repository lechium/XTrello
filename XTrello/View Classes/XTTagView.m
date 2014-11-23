//
//  XTTagView.m
//  XTrello
//
//  Created by Kevin Bradley on 7/11/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "XTTagView.h"

@implementation XTTagView

- (id)initWithFrame:(NSRect)frame andColor:(NSColor *)bgColor
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        self.backgroundColor = bgColor;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
  //  NSLog(@"drawRect");
    [[self backgroundColor] setFill];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
   
}



/*
 

 if ([[theLabel lowercaseString] isEqualToString:@"bug"]) colorString = @"red";
 if ([[theLabel lowercaseString] isEqualToString:@"testing"]) colorString = @"purple";
 if ([[theLabel lowercaseString] isEqualToString:@"feature"]) colorString = @"blue";
 
 */


//40x4

//6*44
//264 max size?


@end
