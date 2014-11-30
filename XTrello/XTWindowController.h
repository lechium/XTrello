//
//  XTWindowController.h
//  XTrello
//
//  Created by Kevin Bradley on 7/14/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XTTableView.h"
#import <WebKit/WebKit.h>
#import "XTTrelloCardView.h"
#import "XTrelloItem.h"

@protocol XTWindowControllerDelegate <NSObject>

- (void)removeItemForWindowTag:(NSInteger)windowTag;
- (void)addItemForWindowTag:(NSInteger)windowTag;
@end

@interface XTWindowController : NSWindowController <XTTrelloCardViewDelegate, NSWindowDelegate>
{
    NSArray *currentCardList;
    IBOutlet XTTableView *listTableView;
  //  NSString *currentBoard;
    NSString *currentList;
    NSScrollView *theView;
    XTTrelloCardView *selectedView;
    NSInteger editingRow;
    
    XTTagViewController *tagViewController;
    IBOutlet WebView *webView;
    IBOutlet NSPopUpButton *boardPopup;
    
    IBOutlet NSArrayController *boardListController;
    IBOutlet NSArrayController *boardArrayController;
    IBOutlet NSWindow *prefWindow;
    IBOutlet NSTextField *apiKeyField;
}
@property (nonatomic, assign) IBOutlet NSWindow *windowTwo;
@property (nonatomic, assign) id delegate;
@property (nonatomic, strong) NSString *currentBoard;
@property (nonatomic, assign) NSRange selectedLineRange;
@property (nonatomic, retain) NSTextView *currentTextView;
@property (nonatomic, assign) long selectedLineNumber;
@property (nonatomic, retain) NSString *focalText;
@property (readwrite, assign) BOOL boardsLoaded;

- (IBAction)helpButtonPressed:(id)sender;
- (int)boardCount;
- (void)delayedResignFirstResponder;
- (NSString *)currentProjectName;
- (void)newCardFromMenu:(id)sender;
- (void)setBoardArrayContent:(NSArray *)boardArray;
- (void)populateCardsFromListNamed:(NSString *)listName inBoard:(NSString *)boardName;
- (void)selectBoardNamed:(NSString *)boardName;
- (IBAction)boardSelected:(id)sender;
- (IBAction)listSelected:(id)sender;
- (IBAction)addNewCard:(id)sender;
- (IBAction)generateToken:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)refresh:(id)sender;
- (void)dataReloaded;
@end
