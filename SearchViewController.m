//
//  SearchViewController.m
//  LA Fitness
//
//  Created by Gina Mullins on 8/6/13.
//  Copyright (c) 2013 Fitness International. All rights reserved.
//

#import "SearchViewController.h"
#import "SearchDetailViewController.h"
#import "ClubListViewController.h"
#import "MapViewController.h"
#import "SearchCell.h"
#import "SearchListInfo.h"
#import "ClubInfo.h"
#import "Database.h"


NSString * const REUSE_SEARCH_ID = @"SearchCell";


@interface SearchViewController ()

@end

@implementation SearchViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.listArray == nil)
    {
        self.listArray = [[NSMutableArray alloc] init];
    }

    [self registerNibs];
    
    // load default - clubs
    self.listSelected = kClubs;
    self.sectionHeader = @"Clubs";
    self.segmentedControl.selectedSegmentIndex = 0;
    
    // add pull to refresh control
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl setTintColor:[UIColor redColor]];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.listTable addSubview:refreshControl];
}

-(void)refresh:(UIRefreshControl*)refreshControl
{
    [self loadListTable:self.segmentedControl.selectedSegmentIndex];
    [refreshControl endRefreshing];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"SearchViewController");
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
    UIImageView *titleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"lafSwoosh.png"]];
    [self.navigationItem setTitleView:titleImage];
    
    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Map"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self action:@selector(mapAction:)];
    [[self navigationItem] setRightBarButtonItem:rightButton];
    
    // setup current location
    [[Location sharedInstance] gpsUpdateLocation];
    
    [self loadListTable:self.segmentedControl.selectedSegmentIndex];
    self.mapButton.hidden = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// load table cells faster and more efficiently
- (void)registerNibs
{
    UINib *searchCellNib = [UINib nibWithNibName:REUSE_SEARCH_ID bundle:[NSBundle bundleForClass:[SearchCell class]]];
    [self.listTable registerNib:searchCellNib forCellReuseIdentifier:REUSE_SEARCH_ID];
}

- (void)loadListTable:(SearchSelected)buttonSelected
{
    [self.listArray removeAllObjects];
    
    switch (buttonSelected)
    {
        case kClubs:
            self.listArray = [NSMutableArray arrayWithArray:[[Database sharedInstance] filteredClubs]];
            self.sectionHeader = @"Clubs";
            break;
            
        case kClasses:
            self.listArray = [NSMutableArray arrayWithArray:[[Database sharedInstance] classes:kALLCLUBS getAll:NO]];
            self.sectionHeader = @"Classes";
            break;
            
        case kAmenities:
            self.listArray = [NSMutableArray arrayWithArray:[[Database sharedInstance] amenities:kALLCLUBS]];
            self.sectionHeader = @"Amenities";
            break;
            
        case kLeagues:
            self.listArray = [NSMutableArray arrayWithArray:[[Database sharedInstance] leagues:kALLCLUBS]];
            self.sectionHeader = @"Leagues";
            
            if ([self.listArray count] == 0)
            {
                [self showAlert:0];
            }
            break;
            
        default:
            break;
    }
    
    [self.listTable reloadData];
}

- (NSInteger)sportNameIndexForLeague:(NSString*)sport
{
    NSInteger index = 0;
    if ([sport isEqualToString:@"BB"])
    {
        index = 0;
    }
    else if ([sport isEqualToString:@"RB"])
    {
        index = 1;
    }
    else if ([sport isEqualToString:@"SQ"])
    {
        index = 2;
    }
    else if ([sport isEqualToString:@"VB"])
    {
        index = 3;
    }
    
    return index;
}

- (void)showAlert:(NSInteger)tag
{
    // for now
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:@"No leagues found within 50 miles,\ncheck your spelling or change\nyour search location above"
                          message:nil
                          delegate:self
                          cancelButtonTitle:@"Continue"
                          otherButtonTitles:nil, nil];
    
    [alert setTag:tag];
    [alert show];
}

- (IBAction)goBack:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)mapAction:(id)sender
{
    MapViewController *mapView = [[MapViewController alloc] initWithNibName:@"MapViewController" bundle:nil];
    mapView.allLocations = [NSMutableArray arrayWithArray:[[Database sharedInstance] filteredClubs]];
    mapView.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    [self.navigationController presentViewController:mapView animated:YES completion:nil];
}

- (IBAction)GPSAction:(id)sender
{
    // todo
    
}

- (IBAction)showSelectedView:(id)sender
{
    NSInteger index = self.segmentedControl.selectedSegmentIndex;
    self.listSelected = index;
    [self loadListTable:index];
    
    [self.listTable reloadData];
    [self.listTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                          atScrollPosition:UITableViewScrollPositionTop animated:YES];
}


#pragma mark - UITextField delegate


// UITextField delegate methods for search text box
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    // dismiss the keyboard - need delay to make it work here
    [self.locationTextField resignFirstResponder];
    if ([self.locationTextField.text length] > 0)
    {
        [self.locationTextField setClearButtonMode:UITextFieldViewModeAlways];
    }
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    // reset the searchBox
    if ([self.locationTextField.text length] > 0)
    {
        [self.locationTextField setText:@""];
        [self.locationTextField resignFirstResponder];
    }
    
    return YES;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
}


#pragma mark Table Data Source and Delegate Methods


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.listArray count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.listTable dequeueReusableCellWithIdentifier:[self reuseSearchIDForRowAtIndexPath:indexPath]];
    if (cell == nil)
    {
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.numberOfLines = 1;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    
    [self configureSearchCell:(SearchCell*)cell forRowAtIndexPath:indexPath];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.listSelected == kClubs)
    {
        ClubInfo *info = [self.listArray objectAtIndex:indexPath.row];
        SearchDetailViewController *detailView = [[SearchDetailViewController alloc] initWithNibName:@"SearchDetailViewController" bundle:nil];
        detailView.clubInfo = info;
        detailView.listSelected = kClubs;
        detailView.headerText = info.desc;
        [self.navigationController pushViewController:detailView animated:YES];
    }
    else
    {
        SearchCell *selectedCell = (SearchCell*)[tableView cellForRowAtIndexPath:indexPath];
        
        ClubListViewController *clubList = [[ClubListViewController alloc] initWithNibName:@"ClubListViewController" bundle:nil];
        clubList.listSelected = self.listSelected;
        clubList.headerText = selectedCell.title.text;
        
        // pass the list of clubs
        if (self.listSelected == kLeagues)
        {
            NSString *sportName = [self.listArray objectAtIndex:indexPath.row];
            clubList.searchID = [self sportNameIndexForLeague:sportName];
        }
        else
        {
            SearchListInfo *info = [self.listArray objectAtIndex:indexPath.row];
            clubList.searchID = info.searchID;
        }
        
        [self.navigationController pushViewController:clubList animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.listSelected == kClasses)
    {
        SearchListInfo *info = [self.listArray objectAtIndex:indexPath.row];
        CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:info.desc];
        
        return size.height + 50;
    }
    
    return 50;      // all other cell heights
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.sectionHeader;
}

- (void)configureSearchCell:(SearchCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // reset
    cell.title.hidden = NO;
    cell.subtitle.hidden = NO;
    cell.miscLabel.hidden = NO;
    cell.imageView.hidden = NO;
    
    // same for all selections
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    [cell.title setFont:[UIFont systemFontOfSize:SearchCell_Title_FontSize]];
    [cell.title setTextColor:[UIColor blackColor]];
    [cell.title setFrame:CGRectMake(7, 2, 250, 21)];
    
    [cell.subtitle setFont:[UIFont fontWithName:@"American Typewriter" size:SearchCell_Subtitle_FontSize]];
    [cell.subtitle setTextColor:[UIColor darkGrayColor]];
    [cell.subtitle setFrame:CGRectMake(7, 23, 200, 21)];
    
    [cell.miscLabel setFont:[UIFont systemFontOfSize:SearchCell_Misc_FontSize]];
    [cell.miscLabel setTextColor:[UIColor blueColor]];
    
    if (self.listSelected == kClubs)
    {
        ClubInfo *info = [self.listArray objectAtIndex:indexPath.row];
        
        cell.title.text = info.desc;
        cell.subtitle.text = info.city;
        cell.miscLabel.text = [NSString stringWithFormat:@"%i Mi", info.distance];
        cell.imageView.hidden = YES;
    }
    else if (self.listSelected == kClasses)
    {
        SearchListInfo *info = [self.listArray objectAtIndex:indexPath.row];
        
        cell.title.text = info.name;
        cell.subtitle.text = info.desc;
        cell.miscLabel.hidden = YES;
        cell.imageView.hidden = YES;
        
        // resize the label to fit entire description
        cell.subtitle.numberOfLines = 0;
        CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:info.desc];
        [cell.subtitle setFrame:CGRectMake(11, 23, 270, size.height+25)];
        [cell.subtitle setFont:[UIFont fontWithName:@"American Typewriter" size:13]];   // must be the same as stringsize
    }
    else if (self.listSelected == kAmenities)
    {
        SearchListInfo *info = [self.listArray objectAtIndex:indexPath.row];
        
        cell.title.text = info.name;
        cell.imageView.image = [[Utils sharedInstance] imageForAmenity:info.searchID];
        cell.subtitle.hidden = YES;
        cell.miscLabel.hidden = YES;
        
        [cell.title setFrame:CGRectMake(51, 10, 200, 25)];
    }
    else if (self.listSelected == kLeagues)
    {
        // Amenities and Leagues
        NSString *sportName = [self.listArray objectAtIndex:indexPath.row];
        
        cell.title.text = [[Utils sharedInstance] sportNameForLeague:sportName];
        cell.imageView.image = [[Utils sharedInstance] imageForLeague:sportName];
        cell.subtitle.hidden = YES;
        cell.miscLabel.hidden = YES;
        
        [cell.title setFrame:CGRectMake(51, 10, 200, 25)];
    }
}

- (NSString *)reuseSearchIDForRowAtIndexPath:(NSIndexPath*)indexPath
{
    // return the search ID cell
    return REUSE_SEARCH_ID;
}


@end
