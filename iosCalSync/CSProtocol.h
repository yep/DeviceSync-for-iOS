//
//  CSProtocol.h
//  iosCalSync
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

#ifndef iosCalSync_CSProtocol_h
#define iosCalSync_CSProtocol_h

#import <Foundation/Foundation.h>
#include <stdint.h>

// use tcp port 51515 which should be free according to
// https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml
// at time of writing
static const int CSProtocolIPv4PortNumber = 51515;

enum {
    CSCalSyncFrameTypeDeviceInfo = 100,
    CSCalSyncFrameTypePing = 101,
    CSCalSyncFrameTypePong = 102,
    CSCalSyncFrameTypeCalendar = 103,
    CSCalSyncFrameTypeEvent = 104,
};

typedef struct _CSCalSyncEventFrame {
    uint32_t length;
    uint8_t event[0];
} CSCalSyncEventFrame;

// prepare data to be sent data over usb
static dispatch_data_t CSCalSyncDispatchData(NSData *data)
{
    size_t length = data.length;
    CSCalSyncEventFrame *eventFrame = CFAllocatorAllocate(nil, sizeof(CSCalSyncFrameTypeEvent) + length, 0);

    memcpy(eventFrame->event, data.bytes, length); // Copy bytes to event array of CSCalSyncEventFrame stuct
    eventFrame->length = htonl(length); // Convert integer to network byte order

    // Wrap the eventFrame in a dispatch data object
    return dispatch_data_create((const void *)eventFrame, sizeof(CSCalSyncEventFrame) + length, nil, ^{
        CFAllocatorDeallocate(nil, eventFrame);
    });
}

#endif /* ifndef iosCalSync_CSProtocol_h */
