//
//  SearchDetailViewController.m
//  LA Fitness
//
//  Created by Gina Mullins on 8/6/13.
//  Copyright (c) 2013 xxxxxxxxxx. All rights reserved.
//

#import "SearchDetailViewController.h"
#import "MapViewController.h"
#import "ClassDetailViewController.h"
#import "ClubHoursInfo.h"
#import "ClassesInfo.h"
#import "SearchCell.h"
#import "ShowButtonsCell.h"
#import "ShowLabelCell.h"
#import "Database.h"
#import "FormatDate.h"
#import "GlobalMethods.h"
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>


// toggle to show sort type
#define kSortClassName  0
#define kSortClassTime  1

NSString * const REUSE_SEARCH_DETAIL_ID = @"SearchCell";
NSString * const REUSE_SHOW_BUTTONS_ID = @"ShowButtonsCell";
NSString * const REUSE_SHOW_LABEL_ID = @"ShowLabelCell";


@interface SearchDetailViewController ()

@property (nonatomic, assign) ABAddressBookRef addressBook;
@property (nonatomic, assign) float listTableHeight;
@property (nonatomic, assign) float listTableHeightForDetails;

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
    [self.sortByClassLabel setBackgroundColor:[UIColor darkGrayColor]];
    [self.sortByTimeLabel setBackgroundColor:[UIColor lightGrayColor]];
    self.isFavoriteClub = NO;
    
    self.sortType = kSortClassName;
    self.displayType = kClubDetails;
    
    if ([[Utils sharedInstance] isIPhone5])
    {
        self.listTableHeight = 364;
        self.listTableHeightForDetails = 454;
    }
    else
    {
        self.listTableHeight = 290;
        self.listTableHeightForDetails = 450;
    }
    
    // first page loaded is always details
    self.listTable.frame = CGRectMake(0, 0, 320, self.listTableHeightForDetails);
    
    
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"SearchDetailViewController");
    [super viewWillAppear:animated];
    
    self.headerLabel.text = self.headerText;
    self.headerLabel.font = [UIFont systemFontOfSize:17];
    self.isFavoriteClub = NO;
    
    [self.tabBar setSelectedItem:[self.tabBar.items objectAtIndex:self.displayType]];
    [self.listTable reloadData];
    
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

- (NSString*)amenitiesStr
{
    NSString *list = @"";
    NSMutableString *all = [NSMutableString string];
    NSArray *DBArray = [[Database sharedInstance] amenitiesForClubID:self.clubInfo.clubID];
    
    if ([DBArray count] > 0)
    {
        // names only
        [all appendString:@"Amenities:\n"];
        for (NSDictionary *info in DBArray)
        {
            NSString *desc = [info valueForKey:@"desc"];    // contains amenity name
            [all appendString:[NSString stringWithFormat:@"%@, ", desc]];
        }
        
        // remove the last comma and last space
        list = [all substringToIndex:[all length] - 2];
    }
    else
    {
        list = @"Amenities:\nNo amenities at this location";
    }
    
    return list;
}

- (NSString*)leaguesStr
{
    NSString *list = @"";
    NSMutableString *all = [NSMutableString string];
    NSArray *DBArray = [[Database sharedInstance] leaguesForClubID:self.clubInfo.clubID];
    
    if ([DBArray count] > 0)
    {
        // already an array of strings
        [all appendString:@"Leagues:\n"];
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
        list = @"Leagues:\nNo leagues at this location";
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
    NSString *message = [NSString stringWithFormat:@"Call Club\n%@", self.clubInfo.desc];
    NSString *message2 = [NSString stringWithFormat:@"1-%@", self.clubInfo.phone];
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:message
                          message:message2
                          delegate:self
                          cancelButtonTitle:@"Cancel"
                          otherButtonTitles:@"Call", nil];
    
    [alert show];
}

- (void)sendEmail
{
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
        mailController.mailComposeDelegate = self;
        
        NSString *clubType = [[GlobalMethods sharedGlobalMethods] getCurrentBrand];
        NSString *body = [NSString stringWithFormat:@"%@\n%@\n%@\n%@, %@",
                                 clubType, self.clubInfo.desc, self.clubInfo.address, self.clubInfo.city, self.clubInfo.state];
        [mailController setSubject:@" "];
        [mailController setMessageBody:body isHTML:NO];
    
        [self presentViewController:mailController animated:YES completion:nil];
        [[mailController navigationBar] setTintColor:[UIColor whiteColor]];

    }
    else
    {
        UIAlertView* myAlert = [[UIAlertView alloc] initWithTitle:@"Unable to send email at this time"
                                                          message:nil
                                                         delegate:nil
                                                cancelButtonTitle:@"OK"
                                                otherButtonTitles:nil];
        [myAlert show];
    }
    
}

// Dismiss email composer UI on cancel / send
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail sent");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            break;
        default:
            break;
    }
    
    [self becomeFirstResponder];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)addToContacts:(id)sender
{
    // make sure we have access
    switch (ABAddressBookGetAuthorizationStatus())
    {
        // we have access
        case  kABAuthorizationStatusAuthorized:
            [self accessGrantedForAddressBook];
            break;
            
        // make a request
        case  kABAuthorizationStatusNotDetermined :
            [self requestAddressBookAccess];
            break;
        
        // no access, let the user know
        case  kABAuthorizationStatusDenied:
        case  kABAuthorizationStatusRestricted:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Privacy Warning"
                                                            message:@"Permission was not granted for Contacts."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
        break;
        
        default:
            break;
    }
}

- (void)newPersonViewController:(ABNewPersonViewController *)newPersonView didCompleteWithNewPerson:(ABRecordRef)person
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

// Prompt the user for access to their Address Book data
-(void)requestAddressBookAccess
{
    ABAddressBookRequestAccessWithCompletion(self.addressBook, ^(bool granted, CFErrorRef error)
    {
        if (granted)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self accessGrantedForAddressBook];
                
            });
        }
    });
}

// This method is called when the user has granted access to their address book data.
-(void)accessGrantedForAddressBook
{
    CFErrorRef error = NULL;
    self.addressBook = ABAddressBookCreateWithOptions(Nil, &error);
    ABRecordRef person = ABPersonCreate();
    
    // add an image
    NSData *dataRef = nil;
    NSString *brandName = @"";
    if ([[[GlobalMethods sharedGlobalMethods]getCurrentBrand] isEqualToString:@"CSC"])
    {
        //dataRef = UIImagePNGRepresentation([UIImage imageNamed:@"swishLogo.png"]);
        brandName = @"City Sports Club";
    }
    else
    {
        dataRef = UIImagePNGRepresentation([UIImage imageNamed:@"lafSwoosh.png"]);
        brandName = @"LA Fitness";
    }
    
    ABPersonSetImageData(person, (__bridge CFDataRef)dataRef, nil);
    
    // club name and brand
    ABRecordSetValue(person, kABPersonFirstNameProperty, (__bridge CFTypeRef)(self.clubInfo.desc), &error);
    ABRecordSetValue(person, kABPersonOrganizationProperty, (__bridge CFTypeRef)(brandName), &error);
    
    // address
    ABMutableMultiValueRef multiAddress = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
    NSMutableDictionary *addressDictionary = [[NSMutableDictionary alloc] init];
    
    [addressDictionary setObject:self.clubInfo.address forKey:(NSString *)kABPersonAddressStreetKey];
    [addressDictionary setObject:self.clubInfo.city forKey:(NSString *)kABPersonAddressCityKey];
    [addressDictionary setObject:self.clubInfo.state forKey:(NSString *)kABPersonAddressStateKey];
    [addressDictionary setObject:[NSString stringWithFormat:@"%i", self.clubInfo.zip] forKey:(NSString *)kABPersonAddressZIPKey];
    
    ABMultiValueAddValueAndLabel(multiAddress, (__bridge CFTypeRef)(addressDictionary), (CFStringRef)@"Address", NULL);
    ABRecordSetValue(person, kABPersonAddressProperty, multiAddress,&error);
    CFRelease(multiAddress);
    
    // phone
    ABMutableMultiValueRef multiPhone = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    ABMultiValueAddValueAndLabel(multiPhone, (__bridge CFTypeRef)(self.clubInfo.phone), kABPersonPhoneMobileLabel, NULL);
    ABRecordSetValue(person, kABPersonPhoneProperty, multiPhone,nil);
    CFRelease(multiPhone);
    
    ABAddressBookAddRecord(self.addressBook, person, &error);
    
    // show the new contact
    ABNewPersonViewController *controller = [[ABNewPersonViewController alloc] init];
    controller.newPersonViewDelegate = self;
    [controller setTitle:@" "];     // using logo for title background
    
    controller.displayedPerson = person;
    
    UINavigationController *newNavigationController = [[UINavigationController alloc] initWithRootViewController:controller];
    
    [[newNavigationController navigationBar] setTintColor:[UIColor whiteColor]];
    [self presentViewController:newNavigationController animated:YES completion:nil];
    
    CFRelease(person);
}

- (void)loadClassesBySort
{
    if (self.sortType == kSortClassName)
    {
        self.listArray = [NSArray arrayWithArray:[[Database sharedInstance] classNamesForClubID:self.clubInfo.clubID]];
    }
    else
    {
        self.listArray = [NSArray arrayWithArray:[[Database sharedInstance] classInfoForClubID:self.clubInfo.clubID]];
        
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

- (IBAction)sortByAction:(id)sender
{
    UIButton *button = (UIButton*)sender;
    
    // toggle the labels
    if (button.tag == kSortClassName)
    {
        self.sortType = kSortClassName;
        [self.sortByClassLabel setBackgroundColor:[UIColor darkGrayColor]];
        [self.sortByTimeLabel setBackgroundColor:[UIColor lightGrayColor]];
    }
    else
    {
        self.sortType = kSortClassTime;
        [self.sortByClassLabel setBackgroundColor:[UIColor lightGrayColor]];
        [self.sortByTimeLabel setBackgroundColor:[UIColor darkGrayColor]];
    }
    
    [self loadClassesBySort];
}


#pragma mark Tab Bar Delegate


- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    self.displayType = [item tag];
    self.listTable.frame = CGRectMake(0, 90, 320, self.listTableHeight);
    
    switch (self.displayType)
    {
        case kClubDetails:
            self.listTable.frame = CGRectMake(0, 0, 320, self.listTableHeightForDetails);
            break;
            
        case kClubHours:
            self.listArray = [NSArray arrayWithArray:[[Database sharedInstance] clubHoursForClubID:self.clubInfo.clubID]];
            self.messageLabel.text = @"Holidays May Vary";
            self.sortButtonsContainer.hidden = YES;
            break;
            
        case kClubClasses:
            self.messageLabel.text = @"Schedule subject to change";
            [self loadClassesBySort];
            self.sortButtonsContainer.hidden = NO;
            break;
            
        default:
            break;
    }
    
    [self.listTable reloadData];
    [self.listTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                          atScrollPosition:UITableViewScrollPositionTop animated:YES];
}


#pragma mark Table Data Source and Delegate Methods


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.displayType == kClubClasses && self.sortType == kSortClassTime)
    {
        NSInteger sectionCount = [[self.sections allKeys] count];
        return sectionCount;
    }
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // only setup for special cases, otherwise everyone will just have one.
    if (self.displayType == kClubDetails)
    {
        return 6;
    }
    else if (self.displayType == kClubHours)
    {
        return 7;       // days of the week
    }
    else if (self.displayType == kClubClasses)
    {
        if (self.sortType == kSortClassName)
        {
            return [self.listArray count];
        }
        else
        {
            NSArray *array = [[NSArray alloc] initWithArray:[self.sections objectForKey:[[[Utils sharedInstance] daysArray] objectAtIndex:section]]];
            NSInteger rowCount = [array count];
            return rowCount;
        }
    }
    
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.displayType == kClubDetails)
    {
        if (indexPath.row == 0)
        {
            UITableViewCell *cell = [self.listTable dequeueReusableCellWithIdentifier:[self reuseButtonIDForRowAtIndexPath:indexPath]];
            [self configureButtonCell:(ShowButtonsCell*)cell forRowAtIndexPath:indexPath];
            return cell;
        }
        else if (indexPath.row >= 4)
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
    
    if (self.displayType == kClubDetails)
    {
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
        [cell.imageView setHidden:NO];
        
        if (indexPath.row == 1)
        {
            cell.title.text = self.clubInfo.address;
            cell.subtitle.text = [NSString stringWithFormat:@"%@, %@ %i", self.clubInfo.city, self.clubInfo.state, self.clubInfo.zip];
            [cell.imageView setImage:[UIImage imageNamed:@"LocatorIcon.png"]];
            [cell.title setFrame:CGRectMake(51, 4, 200, 20)];
            [cell.subtitle setFrame:CGRectMake(51, 28, 200, 20)];
        }
        if (indexPath.row == 2)
        {
            cell.title.text = self.clubInfo.phone;
            cell.subtitle.hidden = YES;
            [cell.imageView setImage:[UIImage imageNamed:@"PhoneIcon.png"]];
            [cell.title setFrame:CGRectMake(51, 15, 200, 20)];
        }
        if (indexPath.row == 3)
        {
            cell.title.text = @"Email Address Info";
            cell.subtitle.hidden = YES;
            [cell.imageView setImage:[UIImage imageNamed:@"EmailScheduleIcon.png"]];
            [cell.title setFrame:CGRectMake(51, 15, 200, 20)];
        }
    }
    else if (self.displayType == kClubHours)
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
            cell.contentView.backgroundColor = [UIColor colorWithRed:.95 green:.54 blue:0 alpha:0.2];
        }
    }
    else if (self.displayType == kClubClasses)
    {
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        
        if (self.sortType == kSortClassName)
        {
            cell.subtitle.hidden = YES;
            NSDictionary *info = [self.listArray objectAtIndex:indexPath.row];
            
            cell.title.text = [info valueForKey:@"name"];
            [cell.title setFrame:CGRectMake(10, 15, 200, 20)];
        }
        if (self.sortType == kSortClassTime)
        {
            NSArray *array = [[NSArray alloc] initWithArray:[self.sections objectForKey:[[[Utils sharedInstance] daysArray] objectAtIndex:indexPath.section]]];
            ClassesInfo *info = [array objectAtIndex:indexPath.row];
            
            [cell.title setFont:[UIFont boldSystemFontOfSize:SearchCell_Title_FontSize]];
            cell.title.text = [FormatDate formatTime:info.startTime];
            cell.subtitle.text = info.name;
            [cell.title setFrame:CGRectMake(10, 10, 65, 30)];
            [cell.subtitle setFrame:CGRectMake(80, 10, 200, 30)];
        }
    }
}

- (void)configureButtonCell:(ShowButtonsCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    
    [cell.cellButton1 setImage:[UIImage imageNamed:@"AddPlusIcon.png"] forState:UIControlStateNormal];
    [cell.cellTitle1 setText:@"Add to Contacts"];
    [cell.cellTitle1 setNumberOfLines:3];
    [cell.cellTitle2 setNumberOfLines:3];
    [cell.cellButton1 addTarget:self
                         action:@selector(addToContacts:)
               forControlEvents:UIControlEventTouchUpInside];
    
    BOOL isUserLoggedIn = [[GlobalMethods sharedGlobalMethods] isUserLoggedIn];
    if (isUserLoggedIn)
    {
        cell.cellButton2.hidden = NO;
        cell.cellTitle2.hidden = NO;
        
        [cell.cellTitle1 setFrame:CGRectMake(42, 45, 100, 34)];
        [cell.cellTitle2 setFrame:CGRectMake(172, 45, 120, 34)];
        [cell.cellButton1 setFrame:CGRectMake(72, 7, 40, 40)];
        [cell.cellButton2 setFrame:CGRectMake(212, 7, 40, 40)];
        
        [cell.cellButton2 addTarget:self
                             action:@selector(addToFavorites:)
                   forControlEvents:UIControlEventTouchUpInside];
        
        if (self.isFavoriteClub)
        {
            [cell.cellButton2 setImage:[UIImage imageNamed:@"favorite.png"] forState:UIControlStateNormal];
            [cell.cellTitle2 setText:@"Remove Favorite"];
        }
        else
        {
            [cell.cellButton2 setImage:[UIImage imageNamed:@"AddFavoriteIcon.png"] forState:UIControlStateNormal];
            [cell.cellTitle2 setText:@"Add Club to Favorites"];
        }
    }
    else
    {
        // only allow classDetails
        cell.cellButton2.hidden = YES;
        cell.cellTitle2.hidden = YES;
        
        [cell.cellTitle1 setFrame:CGRectMake(107, 45, 100, 34)];
        [cell.cellButton1 setFrame:CGRectMake(136, 7, 40, 40)];
    }
}

- (void)configureLabelCell:(ShowLabelCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    [cell.cellLabel setFont:[UIFont systemFontOfSize:13]];
    [cell.cellLabel setNumberOfLines:10];
    float labelWidth = 260;     // make it the same for everyone
    
    if (self.displayType == kClubDetails)
    {
        NSString *listStr = @"";
        if (indexPath.row == 4)
        {
            listStr = [self amenitiesStr];
            [cell.cellImageView setImage:[UIImage imageNamed:@"WaterBottleIcon.png"]];
        }
        if (indexPath.row == 5)
        {
            listStr = [self leaguesStr];
            [cell.cellImageView setImage:[UIImage imageNamed:@"BasketballIcon.png"]];
        }
        cell.cellLabel.text = listStr;
        
        CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:listStr];
        [cell.cellLabel setFrame:CGRectMake(40, 5, labelWidth, size.height+30)];
        [cell.cellLabel setTextAlignment:NSTextAlignmentLeft];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.displayType == kClubDetails)
    {
        if (indexPath.row == 1)
        {
            // show club location
            CATransition* transition = [CATransition animation];
            transition.duration = 0.5;
            transition.type = kCATransitionReveal;
            transition.subtype = kCATransitionFromRight;
            [self.navigationController.view.layer addAnimation:transition forKey:kCATransition];
            
            MapViewController *mapView = [[MapViewController alloc] initWithNibName:@"MapViewController" bundle:nil];
            mapView.allLocations = [[NSArray alloc] initWithObjects:self.clubInfo, nil];
            mapView.searchLat = self.clubInfo.lat;
            mapView.searchLon = self.clubInfo.lon;
            
            [self.navigationController pushViewController:mapView animated:NO];
        }
        else if (indexPath.row == 2)
        {
            // call the club
            [self callClub];
        }
        else if (indexPath.row == 3)
        {
            [self sendEmail];
        }
    }
    else if (self.displayType == kClubHours)
    {
        // nothing to do here
        
    }
    else if (self.displayType == kClubClasses)
    {
        NSString *className = @"";
        NSInteger classID = 0;
        
        if (self.sortType == kSortClassName)
        {
            NSDictionary *info = [self.listArray objectAtIndex:indexPath.row];
            className = [info valueForKey:@"name"];
            classID = [[info valueForKey:@"classID"] integerValue];
        }
        if (self.sortType == kSortClassTime)
        {
            NSArray *array = [[NSArray alloc] initWithArray:[self.sections objectForKey:[[[Utils sharedInstance] daysArray] objectAtIndex:indexPath.section]]];
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // only setup for special cases, otherwise everyone will have a height of 50
    if (self.displayType == kClubDetails)
    {
        if (indexPath.row == 0)
        {
            if (indexPath.row == 0)
                return 85.0;
        }
        else if (indexPath.row >= 4)
        {
            NSString *listStr = @"";
            if (indexPath.row == 4)
            {
                listStr = [self amenitiesStr];
            }
            if (indexPath.row == 5)
            {
                listStr = [self leaguesStr];
            }
            CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:listStr];
            
            return size.height + 30;
        }
    }
    else if (self.displayType == kClubHours)
    {
        NSString *listStr  = [[Database sharedInstance] holidayStringForClubID:self.clubInfo.clubID];
        CGSize size = [[Utils sharedInstance] stringSizeForLabelCell:listStr];
        
        return size.height + 25;
    }
    
    return 50;      // all other cell heights
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (self.displayType == kClubClasses && self.sortType == kSortClassTime)
    {
        return [[[Utils sharedInstance] daysArray] objectAtIndex:section];
    }
    
    return nil;
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


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.clubInfo = nil;
    self.listArray = nil;
    self.favoriteClubs = nil;
    self.favoriteClasses = nil;
    self.favoritesPath = nil;
    self.headerText = nil;
    self.sections = nil;
}

- (void)dealloc
{
    if(self.addressBook)
    {
        CFRelease(self.addressBook);
    }
}


@end
