//
//  SearchDetailViewController.h
//  LA Fitness
//
//  Created by Gina Mullins on 8/6/13.
//  Copyright (c) 2013 Fitness International. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ClubInfo.h"
#import "SDSegmentedControl.h"

// enum for selection type
typedef enum _DisplaySelected
{
    kDisplayDetails = 0,
    kDisplayHours,
    kDisplayClasses
} DisplaySelected;


@interface SearchDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

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

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property (weak, nonatomic) IBOutlet UITableView *listTable;
@property (weak, nonatomic) IBOutlet UILabel *headerLabel;


- (IBAction)showSelectedView:(id)sender;

- (NSString*)amenitiesStr;
- (NSString*)leaguesStr;
- (NSString*)sportNameForLeague:(NSString*)sport;
- (NSString*)formatClubHours:(NSInteger)index;
- (NSString*)formatKidsKlubHours:(NSInteger)index;
- (void)callClub;
- (void)loadClassesBySort;

@end
