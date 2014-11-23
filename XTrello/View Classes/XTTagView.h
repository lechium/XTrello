//
//  XTTagView.h
//  XTrello
//
//  Created by Kevin Bradley on 7/11/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface XTTagView : NSView

@property (nonatomic, strong) NSColor *backgroundColor;
- (id)initWithFrame:(NSRect)frame andColor:(NSColor *)bgColor;

@end
