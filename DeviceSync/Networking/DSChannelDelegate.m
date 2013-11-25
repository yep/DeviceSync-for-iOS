//
//  DSChannelDelegate.m
//  DeviceSync
//
// Copyright (c) 2013 Jahn Bertsch
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

#import "PTChannel.h"
#import "DSChannelDelegate.h"
#import "DSProtocol.h"
#import "DSMainViewController.h" // forward declaration

@implementation DSChannelDelegate

- (id)init
{
    self = [super init];
    if (self) {
        if (self.serverChannel == nil) {
            // create a new channel that is listening on our IPv4 port
            self.serverChannel = [PTChannel channelWithDelegate:self];
            [self.serverChannel listenOnPort:DSProtocolIPv4PortNumber IPv4Address:INADDR_LOOPBACK callback:^(NSError *error) {
                if (error) {
                    [self.mainViewController displayMessage:[NSString stringWithFormat:@"Failed to listen on 127.0.0.1:%d: %@", DSProtocolIPv4PortNumber, error]];
                } else {
                    [self.mainViewController displayMessage:@"First, download 'DeviceSync for OS X' on your OS X computer from:\n"];
                    [self.mainViewController displayMessage:@"http://bit.ly/1ikPQmL"];
                    [self.mainViewController displayMessage:@"or"];
                    [self.mainViewController displayMessage:@"https://github.com/yep/DeviceSync-for-OS-X/releases"];

                    [self.mainViewController displayMessage:@"Latest version of 'DeviceSync for OS X' is 1.1"];
                    [self.mainViewController displayMessage:@"Then, plug in USB cable and launch 'DeviceSync for OS X' on your computer to start calendar synchronizaition."];
                }
            }];

        }
    }
    return self;
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
    //DLog(@"didReceiveFrameOfType: %u, %u, %@", type, tag, payload);
    if (type == DSDeviceSyncFrameTypeEvent) {
        DSDeviceSyncFrame *eventFrame = (DSDeviceSyncFrame *)payload.data;
        eventFrame->length = ntohl(eventFrame->length);
        NSString *message = [[NSString alloc] initWithBytes:eventFrame->data length:eventFrame->length encoding:NSUTF8StringEncoding];
        [self.mainViewController displayMessage:[NSString stringWithFormat:@"[%@]: %@", channel.userInfo, message]];
    } else if (type == DSDeviceSyncFrameTypePing && self.peerChannel) {
        [self.peerChannel sendFrameOfType:DSDeviceSyncFrameTypePong tag:tag withPayload:nil callback:nil];
    }
}

// invoked when the channel closed. ff it closed because of an error, error is
// a non-nil NSError object.
- (void)ioFrameChannel:(PTChannel *)channel didEndWithError:(NSError *)error
{
    if (error) {
        [self.mainViewController displayMessage:[NSString stringWithFormat:@"%@ ended with error: %@", channel, error]];
    } else {
        [self.mainViewController displayMessage:@"USB connection to 'DeviceSync for OS X' stopped."];
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
    [self.mainViewController displayMessage:@"USB connection to 'DeviceSync for OS X' established."];
    [self.mainViewController displayMessage:@"Now press the 'Sync' button above."];
    [self.mainViewController displayMessage:@"ONCE AGAIN: ALL DATA ON YOUR OS X DEVICE WILL BE DELETED AND REPLACED WITH DATA FROM IOS!"];

    // send some information about ourselves to the other end
    [self sendDeviceInfo];

    self.connected = YES;
}

#pragma mark - 

- (void)sendDeviceInfo
{
    if (!self.peerChannel) {
        return;
    }

    DLog(@"Sending device info over %@", self.peerChannel);
    UIDevice *device = [UIDevice currentDevice];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          device.name, @"name",
                          device.systemName, @"systemName",
                          device.systemVersion, @"systemVersion",
                          nil];
    dispatch_data_t payload = [info createReferencingDispatchData];
    [self.peerChannel sendFrameOfType:DSDeviceSyncFrameTypeDeviceInfo tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
        if (error) {
            [self.mainViewController displayMessage:[NSString stringWithFormat:@"Failed to send DSDeviceSyncFrameTypeDeviceInfo: %@", error]];
        }
    }];
}



@end
