//
//  SearchViewController.h
//  LA Fitness
//
//  Created by Gina Mullins on 8/6/13.
//  Copyright (c) 2013 Fitness International. All rights reserved.
//

#import <UIKit/UIKit.h>



@class ClubInfo;
@class Database;
@class Location;


@interface SearchViewController : UIViewController
<UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) Database *database;
@property (nonatomic, strong) Location *location;
@property (nonatomic, strong) NSMutableArray *listArray;
@property (nonatomic, strong) NSMutableArray *allCities;
@property (nonatomic, strong) NSMutableArray *autoCompleteArray;
@property (nonatomic, copy) NSString *sectionHeader;
@property (nonatomic, assign) SearchSelected listSelected;
@property (nonatomic, assign) float searchLat;
@property (nonatomic, assign) float searchLon;
@property (nonatomic, assign) NSInteger tabIndex;

// UI

@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet UITableView *listTable;
@property (weak, nonatomic) IBOutlet UITextField *locationTextField;
@property (weak, nonatomic) IBOutlet UIButton *mapButton;
@property (weak, nonatomic) IBOutlet UITabBar *tabBar;
@property (strong, nonatomic) UITableView *autoCompleteTable;


- (IBAction)goBack:(id)sender;
- (IBAction)mapAction:(id)sender;
- (IBAction)GPSAction:(id)sender;
- (IBAction)showAutoCompleteTable:(id)sender;

- (void)loadListTable:(SearchSelected)selected;
- (NSInteger)sportNameIndexForLeague:(NSString*)sport;
- (void)showAlert:(NSInteger)tag;
- (void)createDataForAutoComplete;
- (void)resetAutoCompleteTable;


@end

