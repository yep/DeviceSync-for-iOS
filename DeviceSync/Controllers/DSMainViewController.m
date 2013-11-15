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
#import "DSMainViewController.h"
#import "DSProtocol.h"
#import "EKEvent+NSCoder.h"

@interface DSMainViewController ()
@property (nonatomic, weak) PTChannel *serverChannel;
@property (nonatomic, weak) PTChannel *peerChannel;
@property (nonatomic, assign) BOOL connected;
@end

@implementation DSMainViewController

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

    self.connected = NO;

    self.outputTextView.text = @"";

    // create a new channel that is listening on our IPv4 port
    PTChannel *channel = [PTChannel channelWithDelegate:self];
    [channel listenOnPort:DSProtocolIPv4PortNumber IPv4Address:INADDR_LOOPBACK callback:^(NSError *error) {
        if (error) {
            [self displayMessage:[NSString stringWithFormat:@"Failed to listen on 127.0.0.1:%d: %@", DSProtocolIPv4PortNumber, error]];
        } else {
            [self displayMessage:@"Plug in USB cable and launch 'DeviceSync for OS X' on your computer to start calendar synchronizaition.\n"];
            self.serverChannel = channel;
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)displayMessage:(NSString *)message
{
    NSLog(@">> %@", message);
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
    if (!self.connected) {
        [self displayMessage:@"Can not synchronize calendar: No USB connection."];
    } else {
        [self displayMessage:@"Starting calendar synchronization."];
        [self askForCalendarPermissions];
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
        // we're on iOS 5 or older
        accessGranted = YES;
    }

    if (!accessGranted) {
        [self displayMessage:@"No permissions to access calendar. Please enable calendar access in iOS settings."];
    } else {
        if (self.peerChannel) {
            [self exportEventStore:eventStore];
        } else {
            [self displayMessage:@"Can't export data. Not connected"];
        }
    }
}

- (void)exportEventStore:(EKEventStore *)eventStore
{
    NSArray *calendars = [eventStore calendarsForEntityType:EKEntityTypeEvent];

    for (EKCalendar *calendar in calendars) {
        [self sendCalendar:calendar];

        [self displayMessage:[NSString stringWithFormat:@"Exporting calendar with title '%@'.", calendar.title]];

        NSDate *endDate = [NSDate dateWithTimeIntervalSinceNow:[[NSDate distantFuture] timeIntervalSinceReferenceDate]];
        NSArray *calendarArray = [NSArray arrayWithObject:calendar];
        NSPredicate *fetchCalendarEvents = [eventStore predicateForEventsWithStartDate:[NSDate date] endDate:endDate calendars:calendarArray];
        NSArray *eventList = [eventStore eventsMatchingPredicate:fetchCalendarEvents];

        [self displayMessage:[NSString stringWithFormat:@"Found %lu calendar events.", (unsigned long)eventList.count]];

        for (int i = 0; i < eventList.count; i++) {
            [self sendEvent:[eventList objectAtIndex:i]];

            if (i == 99) {
                [self displayMessage:[NSString stringWithFormat:@"Only exporting first 100 events."]];
                break;
            }
        }
    }
}

#pragma mark - communication

- (void)sendCalendar:(EKCalendar *)calendar
{
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:calendar.title, @"title",
                          nil];
    dispatch_data_t payload = [info createReferencingDispatchData];

    [self.peerChannel sendFrameOfType:DSDeviceSyncFrameTypeCalendar tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
        if (error) {
            NSLog(@"Failed to send DSDeviceSyncFrameTypeCalendar: %@", error);
        }
    }];
}

- (void)sendEvent:(EKEvent *)event
{
    NSData *eventData = [NSKeyedArchiver archivedDataWithRootObject:event];
    dispatch_data_t payload = DSDeviceSyncDispatchData(eventData);

    [self.peerChannel sendFrameOfType:DSDeviceSyncFrameTypeEvent tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
        if (error) {
            NSLog(@"Failed to send event: %@", error);
        }
    }];

    [self displayMessage:[NSString stringWithFormat:@"Sending event '%@'", event.title]];
}

- (void)sendDeviceInfo
{
    if (!self.peerChannel) {
        return;
    }

    NSLog(@"Sending device info over %@", self.peerChannel);
    UIDevice *device = [UIDevice currentDevice];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          device.name, @"name",
                          device.systemName, @"systemName",
                          device.systemVersion, @"systemVersion",
                          nil];
    dispatch_data_t payload = [info createReferencingDispatchData];
    [self.peerChannel sendFrameOfType:DSDeviceSyncFrameTypeDeviceInfo tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
        if (error) {
            [self displayMessage:[NSString stringWithFormat:@"Failed to send DSDeviceSyncFrameTypeDeviceInfo: %@", error]];
        }
    }];
}

#pragma mark - PTChannelDelegate

// invoked to accept an incoming frame on a channel. reply no ignore the
// incoming frame. if not implemented by the delegate, all frames are accepted.
- (BOOL)ioFrameChannel:(PTChannel *)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize
{
    if (channel != self.peerChannel) {
        // a previous channel that has been canceled but not yet ended. ignore.
        return NO;
    } else if (type != DSDeviceSyncFrameTypeCalendar && type != DSDeviceSyncFrameTypeEvent && type != DSDeviceSyncFrameTypePing) {
        NSLog(@"Unexpected frame of type %u", type);
        [channel close];
        return NO;
    } else {
        return YES;
    }
}

// invoked when a new frame has arrived on a channel.
- (void)ioFrameChannel:(PTChannel *)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(PTData *)payload
{
    //NSLog(@"didReceiveFrameOfType: %u, %u, %@", type, tag, payload);
    if (type == DSDeviceSyncFrameTypeEvent) {
        DSDeviceSyncEventFrame *eventFrame = (DSDeviceSyncEventFrame *)payload.data;
        eventFrame->length = ntohl(eventFrame->length);
        NSString *message = [[NSString alloc] initWithBytes:eventFrame->event length:eventFrame->length encoding:NSUTF8StringEncoding];
        [self displayMessage:[NSString stringWithFormat:@"[%@]: %@", channel.userInfo, message]];
    } else if (type == DSDeviceSyncFrameTypePing && self.peerChannel) {
        [self.peerChannel sendFrameOfType:DSDeviceSyncFrameTypePong tag:tag withPayload:nil callback:nil];
    }
}

// invoked when the channel closed. ff it closed because of an error, error is
// a non-nil NSError object.
- (void)ioFrameChannel:(PTChannel *)channel didEndWithError:(NSError *)error
{
    if (error) {
        [self displayMessage:[NSString stringWithFormat:@"%@ ended with error: %@", channel, error]];
    } else {
        [self displayMessage:@"USB connection to 'DeviceSync for OS X' stopped."];
        self.connected = NO;
    }
}

// for listening channels, this method is invoked when a new connection has been
// accepted.
- (void)ioFrameChannel:(PTChannel *)channel didAcceptConnection:(PTChannel *)otherChannel fromAddress:(PTAddress *)address
{
    // cancel any other connection. we are fifo, so the last connection
    // established will cancel any previous connection and "take its place"
    if (self.peerChannel) {
        [self.peerChannel cancel];
    }

    // weak pointer to current connection. connection objects live by themselves
    // (owned by its parent dispatch queue) until they are closed
    self.peerChannel = otherChannel;
    self.peerChannel.userInfo = address;
    [self displayMessage:@"USB connection to 'DeviceSync for OS X' established."];

    // send some information about ourselves to the other end
    [self sendDeviceInfo];

    self.connected = YES;
}

@end
