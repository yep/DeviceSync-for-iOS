//
//  DSMainViewController.m
//  DeviceSync
//
// Copyright (c) 2013 Jahn Bertsch
// Copyright (c) 2012 Rasmus Andersson <http://rsms.me/>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <EventKit/EventKit.h>
#import <AddressBookUI/AddressBookUI.h>
#import "RESideMenu.h"
#import "DSMainViewController.h"
#import "DSProtocol.h"
#import "DSChannelDelegate.h"
#import "EKEvent+NSCoder.h"

@interface DSMainViewController ()
@end

@implementation DSMainViewController

#pragma mark - view controller lifecycle

- (void)awakeFromNib
{
    DLog(@"awakeFromNib %p", self);
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // defaults
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"contactsSyncEnabled"] == nil ||
        [[NSUserDefaults standardUserDefaults] objectForKey:@"calendarSyncEnabled"] == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"contactsSyncEnabled"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"calendarSyncEnabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"contactsSyncEnabled"]) {
        self.contactsSwitch.on = NO;
    }
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"calendarSyncEnabled"]) {
        self.calendarSwitch.on = NO;
    }

    self.outputTextView.text = @"";
    self.syncButton.enabled = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    DLog(@"dealloc %p", self);
}

#pragma mark - ui

- (void)displayMessage:(NSString *)message
{
    DLog(@">> %@", message);
    NSString *text = self.outputTextView.text;

    if (text.length == 0) {
        self.outputTextView.text = [text stringByAppendingString:message];
    } else {
        self.outputTextView.text = [text stringByAppendingFormat:@"\n%@\n", message];
        [self.outputTextView scrollRangeToVisible:NSMakeRange(self.outputTextView.text.length, 0)];
    }
}

- (IBAction)syncButtonPressed:(id)sender
{
    if (!self.channelDelegate.connected) {
        [self displayMessage:@"Can not synchronize calendar: No USB connection."];
        [self displayMessage:@"Is the USB cable plugged in and is 'DeviceSync for OS X' running on your computer?"];
    } else {
        if (!self.calendarSwitch.on && !self.contactsSwitch.on) {
            [self displayMessage:@"Either enable contact or calendar synchronization."];
        } else {
            if (self.calendarSwitch.on) {
                [self displayMessage:@"Starting calendar synchronization."];
                [self askForCalendarPermissions];
            }
            if (self.contactsSwitch.on) {
                [self displayMessage:@"Starting contacts synchronization."];
                [self askForContactsPermissions];
            }
        }
    }
}

- (IBAction)menuButtonPressed:(id)sender
{
    [self.sideMenuViewController presentMenuViewController];
}

- (IBAction)switchValueChanged:(UISwitch *)sender {
    if (sender == self.contactsSwitch) {
        [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"contactsSyncEnabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else if (sender == self.calendarSwitch) {
        [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"calendarSyncEnabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - calendar

- (void)askForCalendarPermissions
{
    EKEventStore *eventStore = [[EKEventStore alloc] init];
    __block BOOL accessGranted = NO;

    if ([eventStore respondsToSelector:@selector(requestAccessToEntityType:completion:)]) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
            accessGranted = granted;
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    } else {
        // ios 5 or older
        accessGranted = YES;
    }

    if (!accessGranted) {
        [self displayMessage:@"No permissions to access calendar. Please enable calendar access in iOS settings."];
    } else {
        if (self.channelDelegate.peerChannel) {
            self.outputTextView.dataDetectorTypes = UIDataDetectorTypeNone; // disable for performance
            [self exportEventStore:eventStore];
        } else {
            [self displayMessage:@"Can't export data. Not connected"];
        }
    }
}

- (void)exportEventStore:(EKEventStore *)eventStore
{
    self.outputTextView.dataDetectorTypes = UIDataDetectorTypeNone; // disable for performance

    NSArray *calendars = [eventStore calendarsForEntityType:EKEntityTypeEvent];

    for (EKCalendar *calendar in calendars) {
        [self sendCalendar:calendar];

        [self displayMessage:[NSString stringWithFormat:@"Exporting calendar with title '%@'.", calendar.title]];

        NSArray *calendarArray = [NSArray arrayWithObject:calendar];
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateStyle:NSDateFormatterShortStyle];

        // sync range
        NSInteger futureDays = [[NSUserDefaults standardUserDefaults] integerForKey:@"futureDays"];
        NSInteger pastDays = [[NSUserDefaults standardUserDefaults] integerForKey:@"pastDays"];
        DLog(@"past days=%ld", (long)pastDays);
        DLog(@"future days=%ld", (long)futureDays);

        NSDateComponents *futureDaysComponent = [[NSDateComponents alloc] init];
        futureDaysComponent.day = futureDays;
        NSDateComponents *pastDaysComponent = [[NSDateComponents alloc] init];
        pastDaysComponent.day = -pastDays;

        NSDate *currentDate = [NSDate date];
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *startDate = [calendar dateByAddingComponents:pastDaysComponent toDate:currentDate options:0];
        NSDate *endDate = [calendar dateByAddingComponents:futureDaysComponent toDate:currentDate options:0];

        [self displayMessage:[NSString stringWithFormat:@"Synchronzing from %@ to %@.", [dateFormat stringFromDate:startDate], [dateFormat stringFromDate:endDate]]];

        NSPredicate *fetchCalendarEvents = [eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:calendarArray];
        NSArray *eventList = [eventStore eventsMatchingPredicate:fetchCalendarEvents];

        [self displayMessage:[NSString stringWithFormat:@"Found %lu calendar events.", (unsigned long)eventList.count]];

        for (int i = 0; i < eventList.count; i++) {
            [self sendEvent:[eventList objectAtIndex:i]];
        }

        self.outputTextView.dataDetectorTypes = UIDataDetectorTypeLink; // was disabled for performance
    }
}

#pragma mark - contacts

- (void)askForContactsPermissions
{
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    __block BOOL accessGranted = NO;

    if (ABAddressBookRequestAccessWithCompletion != NULL) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            accessGranted = granted;
            dispatch_semaphore_signal(semaphore);
        });
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    else {
        // ios 5 or older
        accessGranted = YES;
    }

    if (!accessGranted) {
        [self displayMessage:@"No permissions to access contacts. Please enable contacts access in iOS settings."];
    } else {
        if (self.channelDelegate.peerChannel) {
            [self exportAddressBook:addressBook];
        } else {
            [self displayMessage:@"Can't export data. Not connected"];
        }
    }
}

- (void)exportAddressBook:(ABAddressBookRef)addressBook
{
    CFArrayRef peopleArrayRef = ABAddressBookCopyArrayOfAllPeople(addressBook);
    NSArray *people = (__bridge NSArray *)peopleArrayRef;

    for (NSInteger i = 0; i < people.count; i++)
    {
        [self displayMessage:[NSString stringWithFormat:@"Sending contact %ld of %lu.", (long)(i + 1), (unsigned long)people.count]];

        NSArray *person = @[people[i]];
        CFArrayRef personRef = (__bridge CFArrayRef)person;
        NSData *vCard = (NSData *)CFBridgingRelease(ABPersonCreateVCardRepresentationWithPeople(personRef));

        if (i == 0) {
            [self sendContact:vCard first:YES];
        } else {
            [self sendContact:vCard first:NO];
        }
    }
}

#pragma mark - communication

- (void)sendCalendar:(EKCalendar *)calendar
{
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:calendar.title, @"title",
                          nil];
    dispatch_data_t payload = [info createReferencingDispatchData];

    [self.channelDelegate.peerChannel sendFrameOfType:DSDeviceSyncFrameTypeCalendar tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
        if (error) {
            NSLog(@"Failed to send calendar: %@", error);
        }
    }];
}

- (void)sendEvent:(EKEvent *)event
{
    NSData *eventData = [NSKeyedArchiver archivedDataWithRootObject:event];
    dispatch_data_t payload = DSDeviceSyncDispatchData(eventData);

    [self.channelDelegate.peerChannel sendFrameOfType:DSDeviceSyncFrameTypeEvent tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
        if (error) {
            NSLog(@"Failed to send event: %@", error);
        }
    }];

    [self displayMessage:[NSString stringWithFormat:@"Sending event '%@'.", event.title]];
}

- (void)sendContact:(NSData *)vCard first:(BOOL)first
{
    dispatch_data_t payload = DSDeviceSyncDispatchData(vCard);

    // indicate if this is the first contact sent in this sync
    uint32_t tag;
    if (first) {
        tag = DSFrameIsFirstTag;
    } else {
        tag = PTFrameNoTag;
    }

    [self.channelDelegate.peerChannel sendFrameOfType:DSDeviceSyncFrameTypeContact tag:tag withPayload:payload callback:^(NSError *error) {
        if (error) {
            NSLog(@"Failed to send contact: %@", error);
        }
    }];
}

@end
