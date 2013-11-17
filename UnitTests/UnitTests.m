//
//  UnitTests.m
//  UnitTests
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

#import "Specta.h"

SharedExamplesBegin(MySharedExamples)
// Global shared examples are shared across all spec files.

sharedExamplesFor(@"a shared behavior", ^(NSDictionary *data) {
    it(@"should do some stuff", ^{
        // ...
    });
});

SharedExamplesEnd

SpecBegin(Thing)

describe(@"Thing", ^{
    sharedExamplesFor(@"another shared behavior", ^(NSDictionary *data) {
        // Locally defined shared examples can override global shared examples within its scope.
    });

    beforeAll(^{
        // This is run once and only once before all of the examples
        // in this group and before any beforeEach blocks.
    });

    beforeEach(^{
        // This is run before each example.
    });

    it(@"should do stuff", ^{
        // This is an example block. Place your assertions here.
    });

    it(@"should do some stuff asynchronously", ^AsyncBlock {
        // Async example blocks need to invoke done() callback.
        done();
    });

    itShouldBehaveLike(@"a shared behavior", @{@"key" : @"obj"});

    itShouldBehaveLike(@"another shared behavior", ^{
        // Use a block that returns a dictionary if you need the context to be evaluated lazily,
        // e.g. to use an object prepared in a beforeEach block.
        return @{@"key" : @"obj"};
    });

    describe(@"Nested examples", ^{
        it(@"should do even more stuff", ^{
            // ...
        });
    });

    pending(@"pending example");

    pending(@"another pending example", ^{
        // ...
    });

    afterEach(^{
        // This is run after each example.
    });
    
    afterAll(^{
        // This is run once and only once after all of the examples
        // in this group and after any afterEach blocks.
    });
});

SpecEnd
