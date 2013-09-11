//
//  SearchDetailViewController.m
//  LA Fitness
//
//  Created by Gina Mullins on 8/6/13.
//  Copyright (c) 2013 Fitness International. All rights reserved.
//

#import "SearchDetailViewController.h"
#import "MapViewController.h"
#import "ClassDetailViewController.h"
#import "SearchListInfo.h"
#import "ClubHoursInfo.h"
#import "ClassesInfo.h"
#import "SearchCell.h"
#import "ShowButtonsCell.h"
#import "ShowLabelCell.h"
#import "Database.h"
#import "FormatDate.h"


// toggle to show sort type
#define kSortClassName  0
#define kSortClassTime  1

NSString * const REUSE_SEARCH_DETAIL_ID = @"SearchCell";
NSString * const REUSE_SHOW_BUTTONS_ID = @"ShowButtonsCell";
NSString * const REUSE_SHOW_LABEL_ID = @"ShowLabelCell";



@interface SearchDetailViewController ()

@end

@implementation SearchDetailViewController

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
    
    if (self.sections == nil)
        self.sections = [[NSMutableDictionary alloc] init];
    if (self.favoriteClubs == nil)
        self.favoriteClubs = [[NSMutableArray alloc] init];
    if (self.favoriteClasses == nil)
        self.favoriteClasses = [[NSMutableArray alloc] init];
    
    // setup the doc dir path
    NSArray *docDirSearch = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDirPath = [docDirSearch objectAtIndex:0];
    NSString *docDir = [docDirPath stringByAppendingPathComponent:@"data/"];
    self.favoritesPath = [docDir stringByAppendingPathComponent:@"Favorites.plist"];
    
    [self registerNibs];
    
    // make default
    self.sortType = kSortClassName;
    self.isFavoriteClub = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"SearchDetailViewController");
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    UIImageView *titleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"lafSwoosh.png"]];
    [self.navigationItem setTitleView:titleImage];
    self.headerLabel.text = self.headerText;
    
    self.isFavoriteClub = NO;
    
    // look for favorite Clubs and Classes
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:self.favoritesPath])
    {
        [self.favoriteClubs removeAllObjects];
        [self.favoriteClasses removeAllObjects];
        
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:self.favoritesPath];
        self.favoriteClubs = [NSMutableArray arrayWithArray:[dict objectForKey:@"clubIDs"]];
        self.favoriteClasses = [NSMutableArray arrayWithArray:[dict objectForKey:@"classIDs"]];        // keep for saving entire plist later
        
        NSNumber *clubNbr = [NSNumber numberWithInteger:self.clubInfo.clubID];
        if ([self.favoriteClubs containsObject:clubNbr])
        {
            self.isFavoriteClub = YES;
        }
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.listTable reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:YES];
    
    // save favorites before leaving
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:self.favoritesPath])
    {
        [manager removeItemAtPath:self.favoritesPath error:nil];
    }
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    if ([self.favoriteClubs count] > 0)
    {
        [dict setObject:self.favoriteClubs forKey:@"clubIDs"];
    }
    if ([self.favoriteClasses count] > 0)
    {
        [dict setObject:self.favoriteClasses forKey:@"classIDs"];
    }
    
    if ([dict count] > 0)
    {
        [dict writeToFile:self.favoritesPath atomically:YES];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSString*)amenitiesStr
{
    NSString *list = @"";
    NSMutableString *all = [NSMutableString string];
    NSArray *DBArray = [[Database sharedInstance] amenities:self.clubInfo.clubID];
    
    if ([DBArray count] > 0)
    {
        // names only
        for (SearchListInfo *info in DBArray)
        {
            [all appendString:[NSString stringWithFormat:@"%@, ", info.name]];
        }
        
        // remove the last comma and last space
        list = [all substringToIndex:[all length] - 2];
    }
    else
    {
        list = @"No amenities at this location";
    }
    
    return list;
}

- (NSString*)leaguesStr
{
    NSString *list = @"";
    NSMutableString *all = [NSMutableString string];
    NSArray *DBArray = [[Database sharedInstance] leagues:self.clubInfo.clubID];
    
    if ([DBArray count] > 0)
    {
        // already an array of strings
        for (NSString *sport in DBArray)
        {
            NSString *sportName = [self sportNameForLeague:sport];
            [all appendString:[NSString stringWithFormat:@"%@, ", sportName]];
        }
        
        // remove the last comma and last space
        list = [all substringToIndex:[all length] - 2];
    }
    else
    {
        list = @"No leagues at this location";
    }
    
    return list;
}

- (NSString*)sportNameForLeague:(NSString*)sport
{
    NSString *sportName = @"";
    if ([sport isEqualToString:@"BB"])
    {
        sportName = @"Basketball";
    }
    else if ([sport isEqualToString:@"RB"])
    {
        sportName = @"Racquetball";
    }
    else if ([sport isEqualToString:@"SQ"])
    {
        sportName = @"Squash";
    }
    else if ([sport isEqualToString:@"VB"])
    {
        sportName = @"Vollyball";
    }
    
    return sportName;
}

- (NSString*)formatClubHours:(NSInteger)index
{
    NSString *clubHours = @"";
    
    for (ClubHoursInfo *info in self.listArray)
    {
        if (info.scheduleTypeID == 1 && info.dayID == index)
        {
            if (info.open24)
            {
                clubHours = @"Open 24 Hrs";
            }
            else if (info.closed)
            {
                clubHours = @"Closed";
            }
            else
            {
                // get openTime
                NSArray *openArray = [info.openTime componentsSeparatedByString:@":"];
                NSInteger openHour = [[openArray objectAtIndex:0] integerValue];
                NSString *openHourStr = [FormatDate formatHour:openHour];
                
                // get closeTime
                NSArray *closeArray = [info.closeTime componentsSeparatedByString:@":"];
                NSInteger closeHour = [[closeArray objectAtIndex:0] integerValue];
                NSString *closeHourStr = [FormatDate formatHour:closeHour];
                
                clubHours = [NSString stringWithFormat:@"%@ - %@", openHourStr, closeHourStr];
            }
            break;
        }
    }
    return clubHours;
}

- (NSString*)formatKidsKlubHours:(NSInteger)index
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    NSString *clubHours = @"";
    
    for (ClubHoursInfo *info in self.listArray)
    {
        if (info.scheduleTypeID == 2 && info.dayID == index)
        {
            if (info.closed)
            {
                clubHours = @"Closed";
                break;
            }
            NSArray *openArray = [info.openTime componentsSeparatedByString:@":"];
            NSInteger openHour = [[openArray objectAtIndex:0] integerValue];
            NSString *openHourStr = [FormatDate formatHour:openHour];
            
            NSArray *closeArray = [info.closeTime componentsSeparatedByString:@":"];
            NSInteger closeHour = [[closeArray objectAtIndex:0] integerValue];
            NSString *closeHourStr = [FormatDate formatHour:closeHour];
            
            NSString *clubHoursStr = [NSString stringWithFormat:@"%@ - %@\n", openHourStr, closeHourStr];
            [array addObject:clubHoursStr];
        }
    }
    
    NSMutableString *allHours = [NSMutableString string];
    
    for (int i = 0; i < [array count]; i++)
    {
        NSString *hourString = [array objectAtIndex:i];
        [allHours appendString:hourString];
    }
    if ([allHours length] > 0)
    {
        clubHours = [allHours substringToIndex:[allHours length] - 1];
    }
    
    return clubHours;
}

- (void)callClub
{
    NSString *message = [NSString stringWithFormat:@"LA FITNESS\n%@", self.clubInfo.desc];
    NSString *message2 = [NSString stringWithFormat:@"1-%@", self.clubInfo.phone];
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:message
                          message:message2
                          delegate:self
                          cancelButtonTitle:@"Cancel"
                          otherButtonTitles:@"Call", nil];
    
    [alert show];
}

- (void)loadClassesBySort
{
    if (self.sortType == kSortClassName)
    {
        self.listArray = [NSArray arrayWithArray:[[Database sharedInstance] classes:self.clubInfo.clubID getAll:NO]];
    }
    else
    {
        self.listArray = [NSArray arrayWithArray:[[Database sharedInstance] classes:self.clubInfo.clubID getAll:YES]];
        
        // create keys for section and rows
        for (int index = 0; index < [[[Utils sharedInstance] daysArray] count]; index++)
        {
            NSMutableArray *currentArray = [[NSMutableArray alloc] init];
            
            for (ClassesInfo *info in self.listArray)
            {
                if (index == info.dayID)
                {
                    [currentArray addObject:info];
                }
            }
            
            // add to our dictionary
            if ([currentArray count] > 0)
            {
                // sort the array before adding to dict
                NSString *sortString = @"startTime";
                NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortString ascending:YES];
                NSArray *sortedArray = [currentArray sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
                [self.sections setObject:sortedArray forKey:[[[Utils sharedInstance] daysArray] objectAtIndex:index]];
            }
        }
    }
    
    [self.listTable reloadData];
}

- (IBAction)addToFavorites:(id)sender
{
    NSNumber *nbr = [NSNumber numberWithInteger:self.clubInfo.clubID];
    
    if (self.isFavoriteClub)
    {
        self.isFavoriteClub = NO;
        [self.favoriteClubs removeObject:nbr];
    }
    else
    {
        self.isFavoriteClub = YES;
        [self.favoriteClubs addObject:nbr];
    }
    
    [self.listTable reloadData];
}

- (IBAction)addToContacts:(id)sender
{
    NSLog(@"Adding to Contacts");
}

- (IBAction)showClassDetails:(id)sender
{
    NSLog(@"will show class details");
}

- (IBAction)shareInfo:(id)sender
{
    NSLog(@"Adding to Contacts");
}

- (IBAction)showSelectedView:(id)sender
{
    NSInteger index = self.segmentedControl.selectedSegmentIndex;
    
    switch (index)
    {
        case 0:
            self.displayType = kDisplayDetails;
            break;
            
        case 1:
            self.displayType = kDisplayHours;
            self.listArray = [NSArray arrayWithArray:[[Database sharedInstance] clubHours:self.clubInfo.clubID]];
            break;
            
        case 2:
            self.displayType = kDisplayClasses;
            [self loadClassesBySort];
            break;
            
        default:
            break;
    }
    
    [self.listTable reloadData];
    [self.listTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                          atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

// load table cells faster and more efficiently
- (void)registerNibs
{
    UINib *searchCellNib = [UINib nibWithNibName:REUSE_SEARCH_DETAIL_ID bundle:[NSBundle bundleForClass:[SearchCell class]]];
    [self.listTable registerNib:searchCellNib forCellReuseIdentifier:REUSE_SEARCH_DETAIL_ID];
    
    UINib *buttonCellNib = [UINib nibWithNibName:REUSE_SHOW_BUTTONS_ID bundle:[NSBundle bundleForClass:[ShowButtonsCell class]]];
    [self.listTable registerNib:buttonCellNib forCellReuseIdentifier:REUSE_SHOW_BUTTONS_ID];
    
    UINib *labelCellNib = [UINib nibWithNibName:REUSE_SHOW_LABEL_ID bundle:[NSBundle bundleForClass:[ShowLabelCell class]]];
    [self.listTable registerNib:labelCellNib forCellReuseIdentifier:REUSE_SHOW_LABEL_ID];
}

- (IBAction)goBack:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark Table Data Source and Delegate Methods


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.displayType == kDisplayClasses && self.sortType == kSortClassTime)
    {
        NSInteger sectionCount = [[self.sections allKeys] count] + 2;
        return sectionCount;
    }
    else
    {
        return 3;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // only setup for special cases, otherwise everyone will just have one.
    if (self.displayType == kDisplayDetails)
    {
        if (section == 0)
        {
            return 3;
        }
    }
    else if (self.displayType == kDisplayHours)
    {
        if (section == 1)
        {
            return 0;
        }
        else if (section == 2)
        {
            return 7;           // days & hours
        }
    }
    else if (self.displayType == kDisplayClasses)
    {
        if (self.sortType == kSortClassName)
        {
            if (section == 1)
            {
                return [self.listArray count];
            }
            if (section == 2)
            {
                return 0;
            }
        }
        else
        {
            if (section == 1)
            {
                return 0;
            }
            else if (section > 1)
            {
                NSArray *array = [[NSArray alloc] initWithArray:[self.sections objectForKey:[[[Utils sharedInstance] daysArray] objectAtIndex:section-2]]];
                NSInteger rowCount = [array count];
                return rowCount;
            }
        }
    }
    
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.displayType == kDisplayDetails)
    {
        if (indexPath.section == 0)
        {
            if (indexPath.row == 0)
            {
                UITableViewCell *cell = [self.listTable dequeueReusableCellWithIdentifier:[self reuseButtonIDForRowAtIndexPath:indexPath]];
                [self configureButtonCell:(ShowButtonsCell*)cell forRowAtIndexPath:indexPath];
                return cell;
            }
        }
        else
        {
            UITableViewCell *cell = [self.listTable dequeueReusableCellWithIdentifier:[self reuseLabelIDForRowAtIndexPath:indexPath]];
            [self configureLabelCell:(ShowLabelCell*)cell forRowAtIndexPath:indexPath];
            return cell;
        }
    }
    else if (self.displayType == kDisplayHours)
    {
        if (indexPath.section == 0)
        {
            UITableViewCell *cell = [self.listTable dequeueReusableCellWithIdentifier:[self reuseLabelIDForRowAtIndexPath:indexPath]];
            [self configureLabelCell:(ShowLabelCell*)cell forRowAtIndexPath:indexPath];
            return cell;
        }
    }
    
    // all others
    UITableViewCell *cell = [self.listTable dequeueReusableCellWithIdentifier:[self reuseSearchIDForRowAtIndexPath:indexPath]];
    [self configureSearchCell:(SearchCell*)cell forRowAtIndexPath:indexPath];
    return cell;
}

- (void)configureSearchCell:(SearchCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // set default
    cell.contentView.backgroundColor = [UIColor whiteColor];
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    cell.title.hidden = NO;
    cell.subtitle.hidden = NO;
    cell.miscLabel.hidden = YES;
    cell.imageView.hidden = YES;
    [cell.title setFont:[UIFont systemFontOfSize:SearchCell_Title_FontSize]];
    
    if (self.displayType == kDisplayDetails)
    {
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell.imageView setHidden:NO];
        
        if (indexPath.row == 1)
        {
            cell.title.text = self.clubInfo.address;
            cell.subtitle.text = [NSString stringWithFormat:@"%@, %@", self.clubInfo.city, self.clubInfo.state];
            [cell.imageView setImage:[UIImage imageNamed:@"magnify.png"]];
            [cell.title setFrame:CGRectMake(51, 4, 200, 20)];
            [cell.subtitle setFrame:CGRectMake(51, 28, 200, 20)];
        }
        if (indexPath.row == 2)
        {
            cell.title.text = self.clubInfo.phone;
            cell.subtitle.hidden = YES;
            [cell.imageView setImage:[UIImage imageNamed:@"phone.png"]];
            [cell.title setFrame:CGRectMake(51, 15, 200, 20)];
        }
    }
    else if (self.displayType == kDisplayHours)
    {
        if (indexPath.section == 2)
        {
            [cell.title setFont:[UIFont boldSystemFontOfSize:SearchCell_Title_FontSize]];
            cell.title.text = [[[[Utils sharedInstance] daysArray] objectAtIndex:indexPath.row] substringToIndex:3];        // abbreviate days of the week
            cell.subtitle.text = [self formatClubHours:indexPath.row];
            cell.miscLabel.text = [self formatKidsKlubHours:indexPath.row];
            cell.miscLabel.hidden = NO;
            [cell.title setFrame:CGRectMake(15, 14, 65, 21)];
            [cell.subtitle setFrame:CGRectMake(80, 14, 125, 21)];
            [cell.miscLabel setFrame:CGRectMake(205, 5, 107, 40)];
            
            if (indexPath.row == [FormatDate dayOfTheWeek])
            {
                // highlight this row
                cell.contentView.backgroundColor = [UIColor colorWithRed:.78 green:.88 blue:.99 alpha:.5];
            }
        }
    }
    else if (self.displayType == kDisplayClasses)
    {
        if (indexPath.section == 0)
        {
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            cell.subtitle.hidden = YES;
            cell.imageView.hidden = NO;
            NSString *rowText = (self.sortType) ? @"Sort by Class Name" : @"Sort by Class Time";
            cell.title.text = rowText;
            [cell.imageView setImage:[UIImage imageNamed:@"switch.png"]];
            [cell.title setFrame:CGRectMake(51, 15, 200, 20)];
        }
        else if (indexPath.section == 1)
        {
            if (self.sortType == kSortClassName)
            {
                [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                cell.subtitle.hidden = YES;
                ClassesInfo *info = [self.listArray objectAtIndex:indexPath.row];
                cell.title.text = info.name;
                [cell.title setFrame:CGRectMake(10, 15, 200, 20)];
            }
        }
        else if (indexPath.section > 1)
        {
            if (self.sortType == kSortClassTime)
            {
                NSArray *array = [[NSArray alloc] initWithArray:[self.sections objectForKey:[[[Utils sharedInstance] daysArray] objectAtIndex:indexPath.section-2]]];
                ClassesInfo *info = [array objectAtIndex:indexPath.row];
                
                [cell.title setFont:[UIFont boldSystemFontOfSize:SearchCell_Title_FontSize]];
                cell.title.text = [FormatDate formatTime:info.startTime];
                cell.subtitle.text = info.name;
                [cell.title setFrame:CGRectMake(10, 10, 65, 30)];
                [cell.subtitle setFrame:CGRectMake(80, 10, 200, 30)];
            }
        }
    }
}

- (void)configureButtonCell:(ShowButtonsCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    
    [cell.cellButton1 addTarget:self
                         action:@selector(addToFavorites:)
               forControlEvents:UIControlEventTouchUpInside];
    [cell.cellButton2 addTarget:self
                         action:@selector(addToContacts:)
               forControlEvents:UIControlEventTouchUpInside];
    [cell.cellButton3 setImage:[UIImage imageNamed:@"chat.png"] forState:UIControlStateNormal];
    [cell.cellTitle3 setText:@"Share Info"];
    [cell.cellButton3 addTarget:self
                         action:@selector(shareInfo:)
               forControlEvents:UIControlEventTouchUpInside];
    
    if (self.isFavoriteClub)
    {
        [cell.cellButton1 setImage:[UIImage imageNamed:@"favorite.png"] forState:UIControlStateNormal];
        [cell.cellTitle1 setText:@"Remove Favorite"];
    }
    else
    {
        [cell.cellButton1 setImage:[UIImage imageNamed:@"favoriteAdd.png"] forState:UIControlStateNormal];
        [cell.cellTitle1 setText:@"Add Club to Favorites"];
    }
}

- (void)configureLabelCell:(ShowLabelCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    [cell.cellLabel setFont:[UIFont fontWithName:@"American Typewriter" size:13]];
    [cell.cellLabel setNumberOfLines:10];
    float labelWidth = 290;     // make it the same for everyone
    
    if (self.displayType == kDisplayDetails)
    {
        NSString *listStr = @"";
        if (indexPath.section == 1)
        {
            listStr = [self amenitiesStr];
        }
        else
        {
            listStr = [self leaguesStr];
        }
        cell.cellLabel.text = listStr;
        
        CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:listStr];
        [cell.cellLabel setFrame:CGRectMake(10, 5, labelWidth, size.height+10)];
        [cell.cellLabel setTextAlignment:NSTextAlignmentLeft];
    }
    else if (self.displayType == kDisplayHours)
    {
        NSString *listStr = [[Database sharedInstance] holidayString:self.clubInfo.clubID];
        cell.cellLabel.text = listStr;
        
        CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:listStr];
        
        [cell.cellLabel setFrame:CGRectMake(160-(labelWidth/2), 5, labelWidth, size.height+20)];
        [cell.cellLabel setTextAlignment:NSTextAlignmentCenter];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.displayType == kDisplayDetails)
    {
        if (indexPath.section == 0)
        {
            if (indexPath.row == 1)
            {
                // show club location
                MapViewController *mapView = [[MapViewController alloc] initWithNibName:@"MapViewController" bundle:nil];
                NSArray *loc = [[NSArray alloc] initWithObjects:self.clubInfo, nil];
                mapView.allLocations = loc;
                mapView.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
                [self.navigationController presentViewController:mapView animated:YES completion:nil];
            }
            else if (indexPath.row == 2)
            {
                // call the club
                [self callClub];
            }
        }
    }
    else if (self.displayType == kDisplayHours)
    {
        // nothing to do here
        
    }
    else if (self.displayType == kDisplayClasses)
    {
        if (indexPath.section == 0)
        {
            // sort by class name or time
            self.sortType = !self.sortType;
            [self loadClassesBySort];
        }
        else
        {
            NSString *className = @"";
            NSInteger classID = 0;
            
            if (indexPath.section == 1)
            {
                SearchListInfo *info = [self.listArray objectAtIndex:indexPath.row];
                className = info.name;
                classID = info.searchID;
            }
            if (indexPath.section > 1)
            {
                NSArray *array = [[NSArray alloc] initWithArray:[self.sections objectForKey:[[[Utils sharedInstance] daysArray] objectAtIndex:indexPath.section-2]]];
                ClassesInfo *info = [array objectAtIndex:indexPath.row];
                className = info.name;
                classID = info.classID;
            }
            
            ClassDetailViewController *classDetail = [[ClassDetailViewController alloc] initWithNibName:@"ClassDetailViewController" bundle:nil];
            classDetail.clubName = self.headerText;
            classDetail.className = className;
            classDetail.classID = classID;
            classDetail.clubID = self.clubInfo.clubID;
            
            [self.navigationController pushViewController:classDetail animated:YES];
        }
    }
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionHeader = @"";
    
    // only setup for special cases, otherwise everyone will just have one.
    if (self.displayType == kDisplayDetails)
    {
        if (section == 0)
        {
            sectionHeader = @"Location";
        }
        else if (section == 1)
        {
            sectionHeader = @"Amenities";
        }
        else if (section == 2)
        {
            sectionHeader = @"Leagues";
        }
    }
    else if (self.displayType == kDisplayHours)
    {
        if (section == 0)
        {
            sectionHeader = @"Holiday Hours (May Vary)";
        }
        else if (section == 1)
        {
            sectionHeader = @"Club Hours:";
        }
        else if (section == 2)
        {
            sectionHeader = @"Day          Hours                     Kids Klub";
        }
    }
    else if (self.displayType == kDisplayClasses)
    {
        if (self.sortType == kSortClassName)
        {
            if (section == 1)
            {
                sectionHeader = @"Classes";
            }
        }
        else
        {
            if (section == 1)
            {
                sectionHeader = @"Schedule Subject to Change";
            }
            else if (section > 1)
            {
                sectionHeader = [[[Utils sharedInstance] daysArray] objectAtIndex:section-2];
            }
        }
    }
    
    return sectionHeader;
}

// not currently working in ios 7
//- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
//{
//    if (self.displayType == kDisplayClasses)
//    {
//        if (self.sortType == kSortClassTime) 
//        {
//            NSArray *indices = @[@"Sort", @"", @"Sun", @"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat"];
//            return indices;
//        }
//    }
//    
//    return nil;
//}

//- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
//{
//    return index;
//}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // only setup for special cases, otherwise everyone will have a height of 50
    if (self.displayType == kDisplayDetails)
    {
        if (indexPath.section == 0)
        {
            if (indexPath.row == 0)
                return 85.0;
        }
        else
        {
            NSString *listStr = @"";
            if (indexPath.section == 1)
            {
                listStr = [self amenitiesStr];
            }
            else
            {
                listStr = [self leaguesStr];
            }
            CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:listStr];
            
            return size.height + 10;
        }
    }
    else if (self.displayType == kDisplayHours)
    {
        if (indexPath.section == 0)
        {
            NSString *listStr  = [[Database sharedInstance] holidayString:self.clubInfo.clubID];
            CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:listStr];
            
            return size.height + 20;
        }
        else
            return 45;
    }
    
    return 50;      // all other cell heights
}

- (NSString *)reuseSearchIDForRowAtIndexPath:(NSIndexPath*)indexPath
{
    // return the ID cell
    return REUSE_SEARCH_DETAIL_ID;
}

- (NSString *)reuseButtonIDForRowAtIndexPath:(NSIndexPath*)indexPath
{
    // return the ID cell
    return REUSE_SHOW_BUTTONS_ID;
}

- (NSString *)reuseLabelIDForRowAtIndexPath:(NSIndexPath*)indexPath
{
    // return the ID cell
    return REUSE_SHOW_LABEL_ID;
}


#pragma mark - UIAlertView Delegate


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
    
    if ([buttonTitle isEqualToString:@"Call"])
    {
        NSString *phoneStr = [NSString stringWithFormat:@"telprompt://1-%@", self.clubInfo.phone];
        NSURL *url = [NSURL URLWithString:phoneStr];
        [[UIApplication sharedApplication] openURL:url];
    }
}


@end
