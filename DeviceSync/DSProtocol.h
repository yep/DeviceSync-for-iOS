//
//  DSProtocol.h
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

#ifndef DeviceSync_DSProtocol_h
#define DeviceSync_DSProtocol_h

#import <Foundation/Foundation.h>
#include <stdint.h>

// use tcp port 51515 which should be free according to
// https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml
// at time of writing
static const int DSProtocolIPv4PortNumber = 51515;

static const uint32_t DSFrameIsFirstTag = 1;

enum DSDeviceSyncFrameType {
    DSDeviceSyncFrameTypeDeviceInfo = 100,
    DSDeviceSyncFrameTypePing = 101,
    DSDeviceSyncFrameTypePong = 102,
    DSDeviceSyncFrameTypeCalendar = 103,
    DSDeviceSyncFrameTypeEvent = 104,
    DSDeviceSyncFrameTypeContact = 105,
};

typedef struct _DSDeviceSyncFrame {
    uint32_t length;
    uint8_t data[0];
} DSDeviceSyncFrame;

// prepare data to be sent data over usb
#pragma clang diagnostic ignored "-Wunused-function" // disable warning about DSDeviceSyncDispatchData being unused.
static dispatch_data_t DSDeviceSyncDispatchData(NSData *data)
{
    size_t length = data.length;
    DSDeviceSyncFrame *frame = CFAllocatorAllocate(nil, sizeof(DSDeviceSyncFrame) + length, 0);

    memcpy(frame->data, data.bytes, length); // copy bytes to event array of DSDeviceSyncFrame stuct
    frame->length = htonl(length); // convert integer to network byte order

    // wrap the eventFrame in a dispatch data object
    return dispatch_data_create((const void *)frame, sizeof(DSDeviceSyncFrame) + length, nil, ^{
        CFAllocatorDeallocate(nil, frame);
    });
}

#endif /* ifndef DeviceSync_DSProtocol_h */
