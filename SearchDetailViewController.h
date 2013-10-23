//
//  SearchDetailViewController.h
//  LA Fitness
//
//  Created by Gina Mullins on 8/6/13.
//  Copyright (c) 2013 xxxxxxxxxx. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import "ClubInfo.h"


@interface SearchDetailViewController : UIViewController
<UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate, MFMailComposeViewControllerDelegate, ABNewPersonViewControllerDelegate>

@property (nonatomic, strong) ClubInfo *clubInfo;
@property (nonatomic, strong) NSArray *listArray;
@property (nonatomic, strong) NSMutableArray *favoriteClubs;
@property (nonatomic, strong) NSMutableArray *favoriteClasses;
@property (nonatomic, copy) NSString *favoritesPath;
@property (nonatomic, copy) NSString *headerText;
@property (nonatomic, strong) NSMutableDictionary *sections;
@property (nonatomic, assign) SearchSelected listSelected;
@property (nonatomic, assign) NSInteger displayType;
@property (nonatomic, assign) NSInteger sortType;
@property (nonatomic, readwrite) BOOL isFavoriteClub;

// UI

@property (weak, nonatomic) IBOutlet UIView *sortButtonsContainer;
@property (weak, nonatomic) IBOutlet UITableView *listTable;
@property (weak, nonatomic) IBOutlet UILabel *headerLabel;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UILabel *sortByClassLabel;
@property (weak, nonatomic) IBOutlet UILabel *sortByTimeLabel;
@property (weak, nonatomic) IBOutlet UITabBar *tabBar;

- (NSString*)amenitiesStr;
- (NSString*)leaguesStr;
- (NSString*)sportNameForLeague:(NSString*)sport;
- (NSString*)formatClubHours:(NSInteger)index;
- (NSString*)formatKidsKlubHours:(NSInteger)index;
- (void)callClub;
- (void)loadClassesBySort;

- (IBAction)sortByAction:(id)sender;

@end
