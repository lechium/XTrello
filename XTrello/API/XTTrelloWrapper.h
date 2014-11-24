//
//  XTTrelloWrapper.h
//  XTrello
//
//  Created by Kevin Bradley on 7/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#define OUR_DATE_FORMAT @"MMddyy_HHmmss"
#define NEW_DATE_FORMAT @"yyyy-MM-dd"
#define HOUR_FORMAT @"HH:mm:SS"

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, XTInitialNoteType) {
    XTToDoType,
    XTBugsType,
    XTActiveType,
    XTBlockedType,
    XTDoneType,
    XTBacklogType,
};

static NSString *const TImprovementLabel =          @"improvment";
static NSString *const TInvestigationLabel =        @"investigation";
static NSString *const TToolLabel       =           @"tool";
static NSString *const TBugLabel            =       @"bug";
static NSString *const TTestingLabel     =          @"testing";
static NSString *const TFeatureLabel       =        @"feature";

@protocol XTTrelloWrapperProtocol;

@interface XTTrelloWrapper : NSObject
{
    NSDate *startDate;
}
@property (readwrite, assign) BOOL dataReady;
@property (readwrite, assign) BOOL reloading;
@property (nonatomic, strong) NSString *sessionToken;
@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, strong) NSString *apiKey;
@property (atomic, strong) NSMutableDictionary *trelloData;
@property (nonatomic, weak) id delegate;

+ (id)sharedInstance;
+ (NSString *)UTCDateFromDate:(NSDate *)theDate;
- (NSDictionary *)addCardToBoard:(NSString *)boardName inList:(NSString *)listName withName:(NSString *)cardName withDescription:(NSString *)theDescription;
- (NSArray *)closedCardsInBoard:(NSString *)boardName;
- (NSDictionary *)deleteCard:(NSDictionary *)theCard inBoardNamed:(NSString *)boardName;
- (NSDictionary *)addMemberId:(NSString *)memberID toCard:(NSDictionary *)theCard inBoardNamed:(NSString *)boardName;
- (NSDictionary *)removeMemberId:(NSString *)memberID fromCard:(NSDictionary *)theCard inBoardNamed:(NSString *)boardName;
- (NSDictionary *)moveCard:(NSDictionary *)theCard toListWithID:(NSString *)listID inBoardNamed:(NSString *)boardName;
- (NSDictionary *)addCardToBoard:(NSString *)boardName inList:(NSString *)listName withName:(NSString *)cardName;
- (NSDictionary *)addCardToBoard:(NSString *)boardName inList:(NSString *)listName withName:(NSString *)cardName inPosition:(NSString *)thePosition;
- (NSString *)initialNoteForType:(XTInitialNoteType)noteType;
- (void)closeBoardWithName:(NSString *)boardName;
- (void)closeListWithName:(NSString *)theList inBoardNamed:(NSString *)boardName;
- (void)closeBoardWithID:(NSString *)boardID;
- (void)closeListWithID:(NSString *)listID;
- (NSDictionary *)updateLocalCard:(NSDictionary *)theCard withName:(NSString *)theName inBoardNamed:(NSString *)boardName;
- (NSDictionary *)updateLocalCardLabels:(NSDictionary *)theCard withList:(NSArray *)theList inBoardNamed:(NSString *)boardName;

- (void)setDueDate:(NSString *)dueDate forCardWithName:(NSString *)cardName inBoardNamed:(NSString *)boardName;
- (void)setDueDate:(NSString *)dueDate forCardWithID:(NSString *)theCard;

- (void)setDefaultLabelsForBoardNamed:(NSString *)boardName;
- (void)moveCardNamed:(NSString *)cardName inBoardNamed:(NSString *)boardName toPosition:(NSString *)newPosition;

- (void)setLabelName:(NSString *)labelName forColor:(NSString *)colorName inBoardWithID:(NSString *)boardID;
- (void)addMemberNamed:(NSString *)memberName toCardWithName:(NSString *)cardName inBoardNamed:(NSString *)boardName;
- (void)addMemberID:(NSString *)memberID toCardWithID:(NSString *)cardID;
- (void)deleteCardWithID:(NSString *)cardID;
- (void)removeMemberNamed:(NSString *)memberName fromCardNamed:(NSString *)cardName inBoard:(NSString *)boardName;
- (void)removeMemberWithID:(NSString *)memberID fromCardID:(NSString *)cardID;
- (NSArray *)cardCommentsFromCardNamed:(NSString *)cardName inBoard:(NSString *)boardName;
- (NSArray *)cardCommentsFromCardID:(NSString *)cardID;
- (void)postComment:(NSString *)theComment toCardNamed:(NSString *)cardName inBoardNamed:(NSString *)boardName;

- (void)postComment:(NSString *)theComment toCardWithID:(NSString *)cardID;
- (void)moveCardNamed:(NSString *)cardName toListWithName:(NSString *)listName inBoardNamed:(NSString *)boardName;
- (void)moveCardWithID:(NSString *)cardID toListWithID:(NSString *)theList;
- (NSDictionary *)createCardWithName:(NSString *)cardName toListWithName:(NSString *)listName inBoardNamed:(NSString *)boardName;
- (NSDictionary *)createCardWithName:(NSString *)cardName toListWithID:(NSString *)listID;
- (void)setDescription:(NSString *)theDesc forCardNamed:(NSString *)cardName inBoardNamed:(NSString *)boardName;
- (void)setDescription:(NSString *)theDesc forCardWithID:(NSString *)theCard;

- (void)deleteLabelID:(NSString *)labelID forCardWithID:(NSString *)theCard;
- (void)addLabelID:(NSString *)labelsString forCardWithID:(NSString *)theCard;
- (void)setLabels:(NSArray *)theLabels forCardNamed:(NSString *)cardName inBoardNamed:(NSString *)boardName;
- (void)setLabels:(NSArray *)theLabels forCardWithID:(NSString *)theCard;
- (NSDictionary *)labelDictionaryFromColor:(NSString *)colorName inBoardNamed:(NSString *)boardName;

- (void)changeListName:(NSString *)theList toName:(NSString *)listName inBoardNamed:(NSString *)boardName;
- (void)changeListWithID:(NSString *)listID toName:(NSString *)listName;
- (void)changeListWithID:(NSString *)listID toPosition:(NSString *)newPosition;
- (void)changeListNamed:(NSString *)theListName inBoard:(NSString *)boardName toPosition:(NSString *)newPosition;
- (void)createListWithName:(NSString *)listName inBoardWithID:(NSString *)boardID inLocation:(NSString *)location;
- (void)createListWithName:(NSString *)listName inBoardNamed:(NSString *)boardName;
- (void)createListWithName:(NSString *)listName inBoardNamed:(NSString *)boardName inLocation:(NSString *)location;
- (NSDictionary *)createBoardWithName:(NSString *)boardName inOrganization:(NSString *)orgName;
- (NSDictionary *)organizationWithNameOrID:(NSString *)organizationName;
- (void)changeBoard:(NSString *)boardName toOrganizationWithNameOrID:(NSString *)organizationName;
- (NSDictionary *)performSynchronousConnectionFromURLRequest:(NSMutableURLRequest *)request;
- (void)createNewTemplateBoardWithName:(NSString *)boardName;
- (void)reloadTrelloData;
- (void)fetchTrelloData;
- (void)loadPreviousData;

- (NSDictionary *)cardWithName:(NSString *)cardName inBoardNamed:(NSString *)boardName;
- (NSDictionary *)listWithName:(NSString *)listName inBoardNamed:(NSString *)boardName;
- (NSArray *)cardsFromListWithName:(NSString *)listName inBoard:(NSString *)boardName;
- (NSDictionary *)boardNamed:(NSString *)boardName;
@end

@protocol XTTrelloWrapperProtocol <NSObject>

- (void)trelloDataFetched:(NSDictionary *)theData;
- (void)trelloDataUpdated:(NSDictionary *)theData;
- (void)setInitialData:(NSDictionary *)theData;
@end