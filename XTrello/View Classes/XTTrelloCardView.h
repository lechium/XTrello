//
//  XTTrelloCardView.h
//  XTrello
//
//  Created by Kevin Bradley on 7/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XTTagView.h"
#import "XTTagViewController.h"

@protocol XTTrelloCardViewDelegate;

@interface XTTrelloCardView : NSTableCellView <NSTextFieldDelegate>
{
    XTTagView *_dividerView;
    NSMenu *context;
    NSMenu *listsMenu;
    NSMenu *memberListMenu;
    NSMenu *boardsMenu;
}
@property (nonatomic, weak) IBOutlet NSTextField *titleView;
@property (nonatomic, strong) XTTagViewController *tagViewController;
@property (nonatomic, strong) NSDictionary *cardDict;
@property (nonatomic, strong) NSString *boardName;
@property (nonatomic, strong) NSString *listName;
@property (nonatomic, weak) id delegate;
- (IBAction)moveCard:(id)sender;
- (IBAction)deleteCard:(id)sender;
- (IBAction)setCardLabels:(id)sender;

- (void)editText;
- (IBAction)textfieldDidEndEditing:(NSTextField *)sender;
- (void)setLabels:(NSArray *)theLabel;
- (void)mouseDownForTextFields:(NSEvent *)theEvent;
- (void)setupView;
- (BOOL)containsLabel:(NSString *)labelName;
@end

@protocol XTTrelloCardViewDelegate <NSObject>

- (NSArray *)boardNames;
- (NSArray *)boardArray;
- (void)jumpToCode:(NSDictionary *)codeDict;
- (void)populateCardsFromListNamed:(NSString *)listName inBoard:(NSString *)boardName;
- (void)addNewCard:(id)sender;
@end