//
//  SearchViewController.h
//  LA Fitness
//
//  Created by Gina Mullins on 8/6/13.
//  Copyright (c) 2013 Fitness International. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SDSegmentedControl.h"



@class ClubInfo;



@interface SearchViewController : UIViewController
<UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>


@property (nonatomic, strong) NSMutableArray *listArray;
@property (nonatomic, copy) NSString *sectionHeader;
@property (nonatomic, assign) SearchSelected listSelected;

// UI

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property (weak, nonatomic) IBOutlet UITableView *listTable;
@property (weak, nonatomic) IBOutlet UITextField *locationTextField;
@property (weak, nonatomic) IBOutlet UIButton *mapButton;


- (IBAction)goBack:(id)sender;
- (IBAction)mapAction:(id)sender;
- (IBAction)GPSAction:(id)sender;
- (IBAction)showSelectedView:(id)sender;

- (void)loadListTable:(SearchSelected)buttonSelected;
- (NSInteger)sportNameIndexForLeague:(NSString*)sport;
- (void)showAlert:(NSInteger)tag;



@end
