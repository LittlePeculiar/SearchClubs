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
#import "ClubInfo.h"
#import "ClassesInfo.h"
#import "PostalInfo.h"
#import "Database.h"
#import "Location.h"


NSString * const REUSE_SEARCH_ID = @"SearchCell";


@interface SearchViewController ()

@property (nonatomic, strong) PostalInfo *currentPostInfo;

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
        self.listArray = [[NSMutableArray alloc] init];
    
    if (self.allCities == nil)
        self.allCities = [[NSMutableArray alloc] init];
    
    if (self.autoCompleteArray == nil)
        self.autoCompleteArray = [[NSMutableArray alloc] init];
    
    if (self.database == nil)
        self.database = [[Database alloc] init];
    if (self.location == nil)
        self.location = [[Location alloc] init];
    
    [self registerNibs];
    
    if (self.tabIndex == kClubs)
    {
        // load default - clubs
        self.listSelected = kClubs;
        self.sectionHeader = @"Clubs";
    }
    else if (self.tabIndex == kClasses)
    {
        // load default - clubs
        self.listSelected = kClasses;
        self.sectionHeader = @"Classes";
    }
    
    // add pull to refresh control
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl setTintColor:[UIColor redColor]];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.listTable addSubview:refreshControl];
}

-(void)refresh:(UIRefreshControl*)refreshControl
{
    [self loadListTable:self.tabIndex];
    [refreshControl endRefreshing];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"SearchViewController");
    [super viewWillAppear:animated];
    
    // add UI changes
    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Map"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self action:@selector(mapAction:)];
    [[self navigationItem] setRightBarButtonItem:rightButton];
    
    [self.tabBar setSelectedItem:[self.tabBar.items objectAtIndex:self.tabIndex]];
    
    // reposition the container view
    if ([[Utils sharedInstance] isIPhone5])
    {
        self.containerView.frame = CGRectMake(0, 455, 320, 50);
    }
    else
    {
        self.containerView.frame = CGRectMake(0, 366, 320, 50);
    }
    
    // setup current location
    [[Location sharedInstance] gpsUpdateLocation];
    
    [self loadListTable:self.tabIndex];
    [self createDataForAutoComplete];
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

- (void)createDataForAutoComplete
{
    [self.allCities removeAllObjects];
    
    // select from DB all cities and zip
    self.allCities = [NSMutableArray arrayWithArray:[self.database allClubLocations]];
    NSLog(@"allCities:%i", [self.allCities count]);
    
    // create table if first time here
    if (self.autoCompleteTable == nil)
    {
        self.autoCompleteTable = [[UITableView alloc] initWithFrame:CGRectMake(85, 95, 235, 120) style:UITableViewStylePlain];
        self.autoCompleteTable.delegate = self;
        self.autoCompleteTable.dataSource = self;
        self.autoCompleteTable.scrollEnabled = YES;
        self.autoCompleteTable.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.autoCompleteTable.hidden = YES;
        [self.view addSubview:self.autoCompleteTable];
    }
}

- (void)loadListTable:(SearchSelected)selected
{
    [self.listArray removeAllObjects];
    
    if ([self.locationTextField.text length] == 0)
    {
        // simple search by current location - need to load clubs for allIDs
        self.searchLat = [[[NSUserDefaults standardUserDefaults] objectForKey:@"currentLat"] floatValue];
        self.searchLon = [[[NSUserDefaults standardUserDefaults] objectForKey:@"currentLon"] floatValue];
        self.listArray = [NSMutableArray arrayWithArray:[self.database filteredClubs]];
        [self loadOthers:selected];
    }
    else
    {
        if ([self isNumeric:self.locationTextField.text])
        {
            [[Utils sharedInstance] showWithStatus:@"Searching..."];
            [self.location retrieveCoords:self.locationTextField.text withCompletionBLock:^(BOOL completed) {
                
                if (completed)
                {
                    [[Utils sharedInstance] dismissStatus];
                    self.searchLat = self.location.searchLat;
                    self.searchLon = self.location.searchLon;
                    
                    // need to look for clubs regardless to create allID's array
                    self.listArray = [NSMutableArray arrayWithArray:[self.database filteredClubsByLat:self.searchLat andLon:self.searchLon]];
                }
                else
                {
                    // no location found for zip
                    NSLog(@"no location found for %@", self.locationTextField.text);
                    self.listArray = [NSMutableArray arrayWithArray:[self.database filteredClubs]];
                    self.locationTextField.text = @"";
                }
                
                [self loadOthers:selected];
                if ([self.listArray count])
                {
                    [self.listTable reloadData];  // need this inside the block
                }
                
            }];
            
            // need to reload again - block doesn't always execute
            self.listArray = [NSMutableArray arrayWithArray:[self.database filteredClubsByLat:self.searchLat andLon:self.searchLon]];
            [self loadOthers:selected];
        }
        else
        {
            // searching by city
            self.searchLat = self.currentPostInfo.latitude;
            self.searchLon = self.currentPostInfo.longitude;
            self.listArray = [NSMutableArray arrayWithArray:[self.database filteredClubsByLat:self.searchLat andLon:self.searchLon]];
            [self loadOthers:selected];
        }
    }
    
    [self.listTable reloadData];
    if ([self.listArray count])
    {
        [self.listTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                              atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}

- (void)loadOthers:(SearchSelected)selected
{
    switch (selected)
    {
        case kClubs:
            self.sectionHeader = @"Clubs";
            break;
            
        case kClasses:
            self.listArray = [NSMutableArray arrayWithArray:[self.database classNamesForClubID:kALLCLUBS]];
            self.sectionHeader = @"Classes";
            break;
            
        case kAmenities:
            self.listArray = [NSMutableArray arrayWithArray:[self.database amenitiesForClubID:kALLCLUBS]];
            self.sectionHeader = @"Amenities";
            break;
            
        case kLeagues:
            self.listArray = [NSMutableArray arrayWithArray:[self.database leaguesForClubID:kALLCLUBS]];
            self.sectionHeader = @"Leagues";
            
            if ([self.listArray count] == 0)
            {
                [self showAlert:0];
            }
            break;
    }
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
    mapView.allLocations = [[NSArray alloc] initWithArray:[self.database filteredClubsByLat:self.searchLat andLon:self.searchLon]];
    mapView.searchLat = self.searchLat;
    mapView.searchLon = self.searchLon;
    mapView.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    [self.navigationController presentViewController:mapView animated:YES completion:nil];
}

- (IBAction)GPSAction:(id)sender
{
    self.locationTextField.text = @"";
    [self loadListTable:self.tabIndex];
}

- (IBAction)showAutoCompleteTable:(id)sender
{
    [self resetAutoCompleteTable];
    UITextField *textField = (UITextField*)sender;
    
    if ([textField.text length] == 0)
    {
        // in case the user backspaces all the way back
        [self.locationTextField performSelector:@selector(resignFirstResponder) withObject:nil afterDelay:0.1];
    }
    else
    {
        // use for cities only
        if (![self isNumeric:textField.text])
        {
            [self.autoCompleteArray removeAllObjects];
            
            [self.allCities enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
             {
                 PostalInfo *info = (PostalInfo*)obj;
                 NSString *searchLower = [textField.text lowercaseString];
                 NSString *cityLower = [info.city lowercaseString];
                 
                 // look for textbox chars in any position
                 NSRange range = [cityLower rangeOfString:searchLower options:NSCaseInsensitiveSearch];
                 
                 if (range.location != NSNotFound)
                 {
                     NSDictionary *dict = @{@"city" : info.city,
                                            @"index" : [NSString stringWithFormat:@"%i", idx] };
                     if (![self.autoCompleteArray containsObject:dict])
                     {
                         [self.autoCompleteArray addObject:dict];
                     }
                 }
             }];
            
            // resize the table if there's less than 10 rows
            if ([self.autoCompleteArray count] > 0 && [self.autoCompleteArray count] < 10)
            {
                float height = ((20 * [self.autoCompleteArray count]) + 10);
                self.autoCompleteTable.frame = CGRectMake(85, 95, 235, height);
            }
            
            if ([self.autoCompleteArray count] > 0)
            {
                [self.autoCompleteTable setHidden:NO];
                [self.autoCompleteTable reloadData];
            }
        }
    }
    
    [self.locationTextField setClearButtonMode:UITextFieldViewModeAlways];
}

- (void)resetAutoCompleteTable
{
    // reset the table
    self.autoCompleteTable.hidden = YES;
    self.autoCompleteTable.frame = CGRectMake(85, 95, 235, 120);
}

- (BOOL)isNumeric:(NSString*)substring
{
    NSScanner *scanner = [NSScanner scannerWithString:substring];
    return [scanner scanInteger:NULL] && [scanner isAtEnd];
}

#pragma mark - UITextField delegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.autoCompleteTable.frame = CGRectMake(85, 95, 235, 120);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    // dismiss the keyboard - need delay to make it work here
    [self.locationTextField performSelector:@selector(resignFirstResponder) withObject:nil afterDelay:0.1];
    [self.locationTextField setClearButtonMode:UITextFieldViewModeAlways];

    if ([self isNumeric:self.locationTextField.text])
    {
        // locations come from zip codes
        [self loadListTable:self.tabIndex];
    }
    else
    {
        // make sure we have something before reloading
        if ([self.locationTextField.text length] > 0 && [self.autoCompleteArray count] > 0)
        {
            [self loadListTable:self.tabIndex];
            [self resetAutoCompleteTable];
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:@"No Clubs Found for Search"
                                  message:nil
                                  delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil, nil];
            
            [alert show];
            self.locationTextField.text = @"";
        }
    }
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    // dismiss the keyboard - need delay to make it work here
    [self.locationTextField performSelector:@selector(resignFirstResponder) withObject:nil afterDelay:0.1];
    
    // reset the searchBox
    if ([self.locationTextField.text length] > 0)
    {
        [self resetAutoCompleteTable];
        [self.locationTextField setText:@""];
    }
    
    return YES;
}


#pragma mark Tab Bar Delegate

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    self.tabIndex = [item tag];
    self.listSelected = self.tabIndex;
    [self loadListTable:self.tabIndex];
}

#pragma mark Table Data Source and Delegate Methods


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.listTable)
        return [self.listArray count];
    else
        return [self.autoCompleteArray count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.listTable)
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
    else
    {
        static NSString *CellIdentifier = @"Cell";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
        
        NSDictionary *info = [self.autoCompleteArray objectAtIndex:indexPath.row];
        NSInteger index = [[info valueForKey:@"index"] integerValue];
        self.currentPostInfo = [self.allCities objectAtIndex:index];
        [cell.textLabel setText:[NSString stringWithFormat:@"%@, %@", self.currentPostInfo.city, self.currentPostInfo.state]];
        [cell.textLabel setFont:[UIFont fontWithName:@"American Typewriter" size:13]];
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.listTable)
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
            clubList.searchLat = self.searchLat;
            clubList.searchLon = self.searchLon;
            clubList.headerText = selectedCell.title.text;
            
            // pass the list of clubs
            if (self.listSelected == kLeagues)
            {
                NSString *sportName = [self.listArray objectAtIndex:indexPath.row];
                clubList.searchID = [self sportNameIndexForLeague:sportName];
            }
            else if (self.listSelected == kAmenities)
            {
                NSDictionary *info = [self.listArray objectAtIndex:indexPath.row];
                clubList.searchID = [[info valueForKey:@"amenityID"] integerValue];
            }
            else
            {
                NSDictionary *info = [self.listArray objectAtIndex:indexPath.row];
                clubList.searchID = [[info valueForKey:@"classID"] integerValue];
            }
            
            [self.navigationController pushViewController:clubList animated:YES];
        }
    }
    else
    {
        // this is the auto complete table
        NSDictionary *info = [self.autoCompleteArray objectAtIndex:indexPath.row];
        NSInteger index = [[info valueForKey:@"index"] integerValue];
        self.currentPostInfo = [self.allCities objectAtIndex:index];
        self.locationTextField.text = [NSString stringWithFormat:@"%@, %@", self.currentPostInfo.city, self.currentPostInfo.state];
        [self resetAutoCompleteTable];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.listTable)
    {
        if (self.listSelected == kClasses)
        {
            NSDictionary *info = [self.listArray objectAtIndex:indexPath.row];
            CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:[info valueForKey:@"desc"]];
            
            return size.height + 55;
        }
        
        return 50;
    }
    else
    {
        // this is the auto complete table
        return 20;
    }
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (tableView == self.listTable)
    {
        return self.sectionHeader;
    }
    
    return nil;
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
    //cell.accessoryView  = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"accessory.png"]];
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
        NSDictionary *info = [self.listArray objectAtIndex:indexPath.row];
        
        cell.title.text = [info valueForKey:@"name"];
        cell.subtitle.text = [info valueForKey:@"desc"];
        cell.miscLabel.hidden = YES;
        cell.imageView.hidden = YES;
        
        // resize the label to fit entire description
        cell.subtitle.numberOfLines = 0;
        CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:cell.subtitle.text];
        [cell.subtitle setFrame:CGRectMake(11, 23, 270, size.height+25)];
        [cell.subtitle setFont:[UIFont fontWithName:@"American Typewriter" size:13]];   // must be the same as stringsize
    }
    else if (self.listSelected == kAmenities)
    {
        NSDictionary *info = [self.listArray objectAtIndex:indexPath.row];
        
        cell.title.text = [info valueForKey:@"desc"];
        cell.imageView.image = [[Utils sharedInstance] imageForAmenity:[[info valueForKey:@"amenityID"] integerValue]];
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
