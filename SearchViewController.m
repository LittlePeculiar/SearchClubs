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
#import "GlobalMethods.h"
#import "DeviceHardware.h"
#import "ReachabilityManager.h"
#import "GAI.h"
#import "GAIDictionaryBuilder.h"

#define kCitySportDefaultZip    @"94538"
#define kLAFitnessDefaultZip    @"92612"


NSString * const REUSE_SEARCH_ID = @"SearchCell";


@interface SearchViewController ()

@property (nonatomic, strong) PostalInfo *currentPostInfo;
@property (nonatomic, readwrite) BOOL hasLeagues;
@property (nonatomic, strong) NSString *lastZipCode;
@property (nonatomic, strong) NSString *clubBrand;

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
        self.sectionHeader = @"Clubs";
    }
    else if (self.tabIndex == kClasses)
    {
        // load default - clubs
        self.sectionHeader = @"Classes";
    }
    
    // add pull to refresh control
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl setTintColor:[UIColor redColor]];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.listTable addSubview:refreshControl];
    
    // setup the GPS button to change the background color
    [self.gpsButton addTarget:self action:@selector(buttonHighlight:) forControlEvents:UIControlEventTouchDown];
    [self.gpsButton addTarget:self action:@selector(buttonNormal:) forControlEvents:UIControlEventTouchUpInside];
    
    // get club brand
    self.clubBrand = [[GlobalMethods sharedGlobalMethods] getCurrentBrand];
    
    // setup zip code in text box
    self.lastZipCode = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultZipcode"];
    if ([self.lastZipCode length] == 0)
    {
        if ([self.clubBrand isEqualToString:@"CSC"])
            self.lastZipCode = kCitySportDefaultZip;
        else
            self.lastZipCode = kLAFitnessDefaultZip;
    }
    
    self.locationTextField.placeholder = self.lastZipCode;
    self.locationTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
}

- (IBAction)buttonHighlight:(id)sender
{
    [self.gpsButton setBackgroundColor:[UIColor colorWithRed:.87 green:.87 blue:.87 alpha:1.0]];
}

- (IBAction)buttonNormal:(id)sender
{
    [self.gpsButton setBackgroundColor:[UIColor clearColor]];
}

-(void)refresh:(UIRefreshControl*)refreshControl
{
    if ([self isNumeric:self.lastZipCode])
        [self loadListTableByZip:self.tabIndex];
    else
        [self loadListTableByCity:self.tabIndex];
    
    [refreshControl endRefreshing];
}

- (void)viewWillAppear:(BOOL)animated
{
    LOG(@"SearchViewController");
    [super viewWillAppear:animated];
    
    if ([self.locationTextField.text length] == 0)
        [self.locationTextField performSelector:@selector(resignFirstResponder) withObject:nil afterDelay:0.01];
    
    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Map"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self action:@selector(mapAction:)];
    
    [[self navigationItem] setRightBarButtonItem:rightButton];
    
    [self.tabBar setSelectedItem:[self.tabBar.items objectAtIndex:self.tabIndex]];
    
    // setup current location
    [[Location sharedInstance] gpsUpdateLocation];
    
    if ([self isNumeric:self.lastZipCode])
        [self loadListTableByZip:self.tabIndex];
    else
        [self loadListTableByCity:self.tabIndex];
    
    [self createDataForAutoComplete];
    self.mapButton.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // save the last zip code searched
    [[NSUserDefaults standardUserDefaults] setObject:self.lastZipCode forKey:@"DefaultZipcode"];
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
    
    // create table if first time here
    if (self.autoCompleteTable == nil)
    {
        self.autoCompleteTable = [[UITableView alloc] initWithFrame:CGRectMake(92, 39, 218, 120) style:UITableViewStylePlain];
        self.autoCompleteTable.delegate = self;
        self.autoCompleteTable.dataSource = self;
        self.autoCompleteTable.scrollEnabled = YES;
        self.autoCompleteTable.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.autoCompleteTable.hidden = YES;
        [self.view addSubview:self.autoCompleteTable];
    }
}

// only called if searching by US zip code since it is ALWAYS numeric
- (void)loadListTableByZip:(SearchSelected)selected
{
    [self.listArray removeAllObjects];
    
    NSString *searchZip = ([self.locationTextField.text length] > 0) ? self.locationTextField.text : self.lastZipCode;
    BOOL isValid = [self.database isZipCodeValid:searchZip];
    if (isValid)
    {
        self.listArray = [NSMutableArray arrayWithArray:[self.database selectClubsWithinDistanceFromZipcode:searchZip]];
        
        if ([self.listArray count] == 0)
        {
            // no clubs for that zip code
            self.locationTextField.text = @"";
            [self loadForLastLocation];
            [self showAlert:1];
        }
        else
        {
            self.searchLat = [self.database searchLat];
            self.searchLon = [self.database searchLon];
            if ([self.locationTextField.text length] > 0)
            {
                self.lastZipCode = self.locationTextField.text;
            }
        }
        
        [self loadOthers:selected];
        if ([self.listArray count])
        {
            [self.listTable reloadData];
            if ([self.listArray count])
            {
                [self.listTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                      atScrollPosition:UITableViewScrollPositionTop animated:YES];
            }
        }
    }
    else
    {
        // calling Location Services for zips not in DB
        NSString *zipWithCountry = [NSString stringWithFormat:@"%@ United States", searchZip];
        
        [[Utils sharedInstance] showWithStatus:@""];
        [self.location retrieveCoords:zipWithCountry withCompletionBLock:^(BOOL completed) {
            
            if (completed)
            {
                [[Utils sharedInstance] dismissStatus];
                self.searchLat = self.location.searchLat;
                self.searchLon = self.location.searchLon;
                
                // need to look for clubs regardless to create allID's array
                self.listArray = [NSMutableArray arrayWithArray:[self.database filteredClubsByLat:self.searchLat andLon:self.searchLon]];
                
                if ([self.listArray count] == 0)
                {
                    // no clubs for that zip code
                    self.locationTextField.text = @"";
                    [self loadForLastLocation];
                    [self showAlert:1];
                }
                else
                {
                    self.searchLat = [self.database searchLat];
                    self.searchLon = [self.database searchLon];
                    if ([self.locationTextField.text length] > 0)
                    {
                        self.lastZipCode = self.locationTextField.text;
                    }
                }
            }
            else
            {
                // returned an error
                [[Utils sharedInstance] dismissStatus];
                self.locationTextField.text = @"";
                [self loadForLastLocation];
            }
            
            [self loadOthers:selected];
            if ([self.listArray count])
            {
                [self.listTable reloadData];
                if ([self.listArray count])
                {
                    [self.listTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                          atScrollPosition:UITableViewScrollPositionTop animated:YES];
                }
            }
        }];
    }
}

- (void)loadListTableByCity:(SearchSelected)selected
{
    // call Location Services
    [self.listArray removeAllObjects];
    NSString *search = ([self.locationTextField.text length] > 0) ? self.locationTextField.text : self.lastZipCode;
    
    [[Utils sharedInstance] showWithStatus:@""];
    [self.location retrieveCoords:search withCompletionBLock:^(BOOL completed) {
        
        if (completed)
        {
            [[Utils sharedInstance] dismissStatus];
            self.searchLat = self.location.searchLat;
            self.searchLon = self.location.searchLon;
            
            // need to look for clubs regardless to create allID's array
            self.listArray = [NSMutableArray arrayWithArray:[self.database filteredClubsByLat:self.searchLat andLon:self.searchLon]];
            
            if ([self.listArray count] == 0)
            {
                // no clubs for that zip code
                self.locationTextField.text = @"";
                [self loadForLastLocation];
                [self showAlert:1];
            }
            else
            {
                self.searchLat = [self.database searchLat];
                self.searchLon = [self.database searchLon];
                if ([self.locationTextField.text length] > 0)
                {
                    // get first record for last successful zip
                    ClubInfo *info = [self.listArray objectAtIndex:0];
                    self.lastZipCode = info.zipCode;
                }
            }
        }
        else
        {
            // returned an error
            [[Utils sharedInstance] dismissStatus];
            self.locationTextField.text = @"";
            [self loadForLastLocation];
        }
        
        [self loadOthers:selected];
        if ([self.listArray count])
        {
            [self.listTable reloadData];
            if ([self.listArray count])
            {
                [self.listTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                      atScrollPosition:UITableViewScrollPositionTop animated:YES];
            }
        }
    }];

}

- (void)loadOthers:(SearchSelected)selected
{
    NSString *GACategory = @"";
    NSString *GAAction = @"";
    NSString *GALabel = @"";
    
    switch (selected)
    {
        case kClubs:
        {
            GACategory = @"Find Club";
            GAAction = @"F_Clubs";
            GALabel = ([self.locationTextField.text length] > 0) ? @"F_Club_NOGPS" : @"F_Club_GPS";
            
            self.sectionHeader = @"Clubs";
            break;
        }
            
        case kClasses:
        {
            GACategory = @"Find Class";
            GAAction = @"F_Classes";
            GALabel = ([self.locationTextField.text length] > 0) ? @"F_Classes_NOGPS" : @"F_Classes_GPS";
            
            self.listArray = [NSMutableArray arrayWithArray:[self.database classNamesForClubID:kALLCLUBS]];
            self.sectionHeader = @"Classes";
            break;
        }
            
        case kAmenities:
        {
            GACategory = @"Amenities";
            GAAction = @"Amenities";
            GALabel = ([self.locationTextField.text length] > 0) ? @"S_Amenities_NOGPS" : @"S_Amenities_GPS";
            
            self.listArray = [NSMutableArray arrayWithArray:[self.database amenitiesForClubID:kALLCLUBS]];
            self.sectionHeader = @"Amenities";
            break;
        }
            
        case kLeagues:
        {
            GACategory = @"Leagues";
            GAAction = @"Leagues";
            GALabel = ([self.locationTextField.text length] > 0) ? @"S_Leagues_NOGPS" : @"S_Leagues_GPS";
            
            self.listArray = [NSMutableArray arrayWithArray:[self.database leaguesForClubID:kALLCLUBS]];
            self.sectionHeader = @"Leagues";
            
            if ([self.listArray count] == 0)
            {
                [self.listTable reloadData];
                self.hasLeagues = NO;
                [self showAlert:0];
            }
            else
                self.hasLeagues = YES;

            break;
        }
    }
    
    // XGoogle Analytics
    NSMutableDictionary *event =
    [[GAIDictionaryBuilder createEventWithCategory:GACategory
                                            action:GAAction
                                             label:GALabel
                                             value:nil] build];
    [[GAI sharedInstance].defaultTracker send:event];
    [[GAI sharedInstance] dispatch];
}

- (void)loadForCurrentLocation
{
    self.searchLat = [[[NSUserDefaults standardUserDefaults] objectForKey:@"currentLat"] floatValue];
    self.searchLon = [[[NSUserDefaults standardUserDefaults] objectForKey:@"currentLon"] floatValue];
    self.listArray = [NSMutableArray arrayWithArray:[self.database filteredClubs]];
    
    if ([self.listArray count])
    {
        ClubInfo *info = [self.listArray objectAtIndex:0];
        self.lastZipCode = info.zipCode;
    }
}

- (void)loadForLastLocation
{
    self.listArray = [NSMutableArray arrayWithArray:[self.database selectClubsWithinDistanceFromZipcode:self.lastZipCode]];
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
    NSString *message = @"";
    NSString *message2 = @"";
    
    if (tag == 0)
    {
        message = @"No leagues found within 50 miles.\nCheck your spelling or change\nyour search location above";
    }
    else if (tag == 1)
    {
        message = @"No Clubs Found for Search";
    }
    else if (tag == 2)
    {
        message = @"No Network Connectivity";
        message2 = @"Your device is not connected to a network. Please check your settings and try again.";
        self.locationTextField.text = @"";
        self.locationTextField.placeholder = self.lastZipCode;
    }
    else if (tag == 3)
    {
        message = @"Zip Code Not Found";
        message2 = @"Please try your search again";
        self.locationTextField.text = @"";
        self.locationTextField.placeholder = self.lastZipCode;
    }
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:message
                          message:message2
                          delegate:self
                          cancelButtonTitle:@"Continue"
                          otherButtonTitles:nil, nil];
    [alert show];
}

- (IBAction)mapAction:(id)sender
{
    // show club location
    CATransition* transition = [CATransition animation];
    transition.duration = 0.6;
    transition.type = kCATransitionReveal;
    transition.subtype = kCATransitionFromBottom;
    [self.navigationController.view.layer addAnimation:transition forKey:kCATransition];
    
    MapViewController *mapView = [[MapViewController alloc] initWithNibName:@"MapViewController" bundle:nil];
    mapView.allLocations = [[NSArray alloc] initWithArray:[self.database filteredClubsByLat:self.searchLat andLon:self.searchLon]];
    mapView.searchLat = self.searchLat;
    mapView.searchLon = self.searchLon;
    
    [self.navigationController pushViewController:mapView animated:NO];
}

- (IBAction)GPSAction:(id)sender
{
    self.locationTextField.text = @"";
    
    if ([[ReachabilityManager sharedManager] isReachable])
    {
        self.locationTextField.placeholder = @"Zip Code";
        [self loadForCurrentLocation];
        [self loadOthers:self.tabIndex];
        if ([self.listArray count])
        {
            [self.listTable reloadData];
            if ([self.listArray count])
            {
                [self.listTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                      atScrollPosition:UITableViewScrollPositionTop animated:YES];
            }
        }
    }
    else
    {
        self.locationTextField.placeholder = self.lastZipCode;
        [self showAlert:2];
    }
}

// connected in IB valueDidChange
- (IBAction)showAutoCompleteTable:(id)sender
{
    [self resetAutoCompleteTable];
    UITextField *textField = (UITextField*)sender;
    
    if ([textField.text length] == 0)
    {
        // in case the user backspaces all the way back
        [self.locationTextField performSelector:@selector(resignFirstResponder) withObject:nil afterDelay:0.01];
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
                self.autoCompleteTable.frame = CGRectMake(92, 39, 218, height);
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
    self.autoCompleteTable.frame = CGRectMake(92, 39, 218, 120);
}

- (BOOL)isNumeric:(NSString*)substring
{
    NSScanner *scanner = [NSScanner scannerWithString:substring];
    return [scanner scanInteger:NULL] && [scanner isAtEnd];
}



#pragma mark - UITextField delegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.autoCompleteTable.frame = CGRectMake(92, 39, 218, 120);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    // dismiss the keyboard - need delay to make it work here
    [self.locationTextField performSelector:@selector(resignFirstResponder) withObject:nil afterDelay:0.01];
    [self.locationTextField setClearButtonMode:UITextFieldViewModeAlways];
    
    if (self.tabIndex == 3 && self.hasLeagues == NO)
    {
        [self showAlert:0];
        self.locationTextField.text = @"";
        return YES;
    }

    // make sure we have something before reloading
    if ([self.locationTextField.text length] > 0)
    {
        if ([self isNumeric:self.locationTextField.text])
        {
            [self loadListTableByZip:self.tabIndex];
        }
        else
        {
            // all other searches, including Canada
            self.locationTextField.text = [self.locationTextField.text uppercaseString];
            [self loadListTableByCity:self.tabIndex];
        }
        
        if ([self.autoCompleteArray count] > 0)
            [self resetAutoCompleteTable];
    }
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    // dismiss the keyboard - need delay to make it work here
    [self.locationTextField performSelector:@selector(resignFirstResponder) withObject:nil afterDelay:0.01];
    
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
    
    if ([self isNumeric:self.lastZipCode])
        [self loadListTableByZip:self.tabIndex];
    else
        [self loadListTableByCity:self.tabIndex];
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
        [cell.textLabel setText:[NSString stringWithFormat:@"%@, %@ %@",
                                 self.currentPostInfo.city, self.currentPostInfo.state, self.currentPostInfo.zipCode]];
        [cell.textLabel setFont:[UIFont systemFontOfSize:11]];
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.listTable)
    {
        if (self.tabIndex == kClubs)
        {
            // XGoogle Analytics
            NSMutableDictionary *event =
            [[GAIDictionaryBuilder createEventWithCategory:@"Find Club"
                                                    action:@"F_Clubs"
                                                     label:@"F_Club_SpecificClub"
                                                     value:nil] build];
            [[GAI sharedInstance].defaultTracker send:event];
            [[GAI sharedInstance] dispatch];
            
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
            clubList.listSelected = self.tabIndex;
            clubList.searchLat = self.searchLat;
            clubList.searchLon = self.searchLon;
            clubList.headerText = selectedCell.title.text;
            
            // pass the list of clubs
            if (self.tabIndex == kLeagues)
            {
                // XGoogle Analytics
                NSMutableDictionary *event =
                [[GAIDictionaryBuilder createEventWithCategory:@"Leagues"
                                                        action:@"Leagues"
                                                         label:@"S_LeagueType"
                                                         value:nil] build];
                [[GAI sharedInstance].defaultTracker send:event];
                [[GAI sharedInstance] dispatch];
                
                NSString *sportName = [self.listArray objectAtIndex:indexPath.row];
                clubList.searchID = [self sportNameIndexForLeague:sportName];
            }
            else if (self.tabIndex == kAmenities)
            {
                // XGoogle Analytics
                NSMutableDictionary *event =
                [[GAIDictionaryBuilder createEventWithCategory:@"Amenities"
                                                        action:@"Amenities"
                                                         label:@"S_SelectAmenity"
                                                         value:nil] build];
                [[GAI sharedInstance].defaultTracker send:event];
                [[GAI sharedInstance] dispatch];
                
                NSDictionary *info = [self.listArray objectAtIndex:indexPath.row];
                clubList.searchID = [[info valueForKey:@"amenityID"] integerValue];
            }
            else
            {
                // XGoogle Analytics
                NSMutableDictionary *event =
                [[GAIDictionaryBuilder createEventWithCategory:@"Find Class"
                                                        action:@"F_Classes"
                                                         label:@"F_Select_Class"
                                                         value:nil] build];
                [[GAI sharedInstance].defaultTracker send:event];
                [[GAI sharedInstance] dispatch];
                
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
        self.locationTextField.text = [NSString stringWithFormat:@"%@, %@ %@",
                                       self.currentPostInfo.city, self.currentPostInfo.state, self.currentPostInfo.zipCode];
        [self resetAutoCompleteTable];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.listTable)
    {
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
    
    [cell.subtitle setFont:[UIFont systemFontOfSize:SearchCell_Subtitle_FontSize]];
    [cell.subtitle setTextColor:[UIColor darkGrayColor]];
    [cell.subtitle setFrame:CGRectMake(7, 23, 200, 21)];
    
    [cell.miscLabel setFont:[UIFont systemFontOfSize:SearchCell_Misc_FontSize]];
    [cell.miscLabel setTextColor:[UIColor blackColor]];
    
    if (self.tabIndex == kClubs)
    {
        ClubInfo *info = [self.listArray objectAtIndex:indexPath.row];
        
        cell.title.text = info.desc;
        cell.subtitle.text = info.city;
        cell.miscLabel.text = [NSString stringWithFormat:@"%i Mi", info.distance];
        [cell.miscLabel setFrame:CGRectMake(240, 10, 50, 32)];
        [cell.miscLabel setTextAlignment:NSTextAlignmentRight];
        cell.imageView.hidden = YES;
    }
    else if (self.tabIndex == kClasses)
    {
        NSDictionary *info = [self.listArray objectAtIndex:indexPath.row];
        
        cell.title.text = [info valueForKey:@"name"];
        cell.subtitle.hidden = YES;
        cell.miscLabel.hidden = YES;
        cell.imageView.hidden = YES;
        
        [cell.title setFrame:CGRectMake(7, 10, 200, 25)];
        
    }
    else if (self.tabIndex == kAmenities)
    {
        NSDictionary *info = [self.listArray objectAtIndex:indexPath.row];
        
        cell.title.text = [info valueForKey:@"desc"];
        cell.imageView.image = [[Utils sharedInstance] imageForAmenity:[[info valueForKey:@"amenityID"] integerValue]];
        cell.subtitle.hidden = YES;
        cell.miscLabel.hidden = YES;
        
        [cell.title setFrame:CGRectMake(51, 10, 200, 25)];
    }
    else if (self.tabIndex == kLeagues)
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.database = nil;
    self.location = nil;
    self.listArray = nil;
    self.allCities = nil;
    self.autoCompleteArray = nil;
    self.sectionHeader = nil;
}

@end
