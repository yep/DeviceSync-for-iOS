//
//  DSSettingsViewController.m
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

#import "DSSettingsViewController.h"
#import "RESideMenu.h"

@interface DSSettingsViewController ()

@end

@implementation DSSettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSInteger futureDays = [[NSUserDefaults standardUserDefaults] integerForKey:@"futureDays"];
    NSInteger pastDays = [[NSUserDefaults standardUserDefaults] integerForKey:@"pastDays"];
    self.futureDaysTextField.text = [@(futureDays) stringValue];
    self.pastDaysTextField.text = [@(pastDays) stringValue];
    [self.futureDaysTextField becomeFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)menuButtonPressed:(id)sender
{
    if (self.isFirstResponder) {
        [self resignFirstResponder];
    }
    [self.sideMenuViewController presentMenuViewController];
}

#pragma mark - UITextInputDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.futureDaysTextField) {
        NSInteger futureDays = [self.futureDaysTextField.text intValue];
        if (futureDays < 1) {
            futureDays = 1;
        } else if (futureDays > 999) {
            futureDays = 999;
        }
        self.futureDaysTextField.text = [@(futureDays) stringValue];

        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setInteger:futureDays forKey:@"futureDays"];
        [userDefaults synchronize];
    } else if (textField == self.pastDaysTextField) {
        NSInteger pastDays = [self.pastDaysTextField.text intValue];
        if (pastDays < 1) {
            pastDays = 1;
        } else if (pastDays > 999) {
            pastDays = 999;
        }
        self.pastDaysTextField.text = [@(pastDays) stringValue];

        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setInteger:pastDays forKey:@"pastDays"];
        [userDefaults synchronize];
    }
}

@end
