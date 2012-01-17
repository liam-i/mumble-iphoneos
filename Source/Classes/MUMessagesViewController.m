/* Copyright (C) 2009-2012 Mikkel Krautz <mikkel@krautz.dk>

   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
   - Neither the name of the Mumble Developers nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <MumbleKit/MKServerModel.h>
#import <MumbleKit/MKTextMessage.h>

#import "MUMessagesViewController.h"
#import "MUMessageBubbleTableViewCell.h"
#import "MUMessageRecipientViewController.h"
#import "MUColor.h"

@interface MUTextMessage : NSObject {
    NSString  *_heading;
    NSString  *_msg;
    NSDate    *_date;
    BOOL      _self;
}
- (id) initWithHeading:(NSString *)heading andMessage:(NSString *)msg andDate:(NSDate *)date andSentBySelf:(BOOL)sentBySelf;
+ (MUTextMessage *) textMessageWithHeading:(NSString *)heading andMessage:(NSString *)msg isSentBySelf:(BOOL)sentBySelf;
- (NSString *) heading;
- (NSString *) message;
- (NSDate *) date;
- (BOOL) isSentBySelf;
@end

@implementation MUTextMessage

- (id) initWithHeading:(NSString *)heading andMessage:(NSString *)msg andDate:(NSDate *)date andSentBySelf:(BOOL)sentBySelf {
    if ((self = [super init])) {
        _heading = [heading retain];
        _msg = [msg retain];
        _date = [date retain];
        _self = sentBySelf;
        // ...
    }
    return self;
}

- (void) dealloc {
    [_heading release];
    [_msg release];
    [_date release];
    [super dealloc];
}

- (NSString *) heading {
    return _heading;
}

- (NSString *) message {
    return _msg;
}

- (NSDate *) date {
    return _date;
}

- (BOOL) isSentBySelf {
    return _self;
}

+ (MUTextMessage *) textMessageWithHeading:(NSString *)heading andMessage:(NSString *)msg isSentBySelf:(BOOL)sentBySelf {
    return [[MUTextMessage alloc] initWithHeading:heading andMessage:msg andDate:[NSDate date] andSentBySelf:sentBySelf];
}
            
@end

@interface MUMessageReceiverButton : UIControl {
    NSString *_str;
}
@end

@implementation MUMessageReceiverButton

- (id) initWithText:(NSString *)str {
    if ((self = [super initWithFrame:CGRectZero])) {
        [self setOpaque:NO];
        if ([str length] >= 15) {
            _str = [[NSString stringWithFormat:@"%@...", [str substringToIndex:11]] retain];
        } else {
            _str = [str copy];
        }
        CGSize size = [_str sizeWithFont:[UIFont boldSystemFontOfSize:14.0f]];
        size.width += 6*2;
        [self setFrame:CGRectMake(0, 0, size.width, size.height)];
    }
    return self;
}

- (void) drawRect:(CGRect)rect {
    rect = self.bounds;
    CGFloat radius = 6.0f;

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);

    CGContextSetLineWidth(context, 1.0f);

    if (self.highlighted)
        [[UIColor lightGrayColor] setFill];
    else
        [[MUColor selectedTextColor] setFill];
    
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, rect.origin.x, rect.origin.y + radius);
    CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + rect.size.height - radius);
    CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + rect.size.height - radius, 
                    radius, M_PI, M_PI / 2, 1); //STS fixed
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width - radius, 
                            rect.origin.y + rect.size.height);
    CGContextAddArc(context, rect.origin.x + rect.size.width - radius, 
                    rect.origin.y + rect.size.height - radius, radius, M_PI / 2, 0.0f, 1);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + radius);
    CGContextAddArc(context, rect.origin.x + rect.size.width - radius, rect.origin.y + radius, 
                    radius, 0.0f, -M_PI / 2, 1);
    CGContextAddLineToPoint(context, rect.origin.x + radius, rect.origin.y);
    CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + radius, radius, 
                    -M_PI / 2, M_PI, 1);
    CGContextClosePath(context);
    
    CGContextFillPath(context);
    
    rect.origin.x = radius;
    rect.size.width -= radius;
    
    [[UIColor whiteColor] set];
    [_str drawInRect:rect withFont:[UIFont boldSystemFontOfSize:14.0f]];
}

- (void) setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}

@end

@interface MUMessagesViewController () <UITableViewDelegate, UITableViewDataSource, MKServerModelDelegate, UITextFieldDelegate, MUMessageBubbleTableViewCellDelegate, MUMessageRecipientViewControllerDelegate> {
    MKServerModel            *_model;
    UITableView              *_tableView;
    UIView                   *_textBarView;
    UITextField              *_textField;
    NSMutableArray           *_messages;

    MKChannel                *_channel;
    MKChannel                *_tree;
    MKUser                   *_user;
}
- (void) setReceiverName:(NSString *)receiver andImage:(NSString *)imageName;
@end

@implementation MUMessagesViewController

- (id) initWithServerModel:(MKServerModel *)model {
    if ((self = [super init])) {
        _model = [model retain];
        [_model addDelegate:self];
        _messages = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) dealloc {
    [_messages release];
    [_model removeDelegate:self];
    [_model release];
    [_textField release];
    [_tableView release];
    [super dealloc];
}

#pragma mark - View lifecycle

- (void) viewDidLoad {
    [super viewDidLoad];

    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-44);
    _tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStylePlain];
    [_tableView setBackgroundView:[[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease]];
    [_tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [_tableView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
    [_tableView setDelegate:self];
    [_tableView setDataSource:self];
    [self.view addSubview:_tableView];
    
    UISwipeGestureRecognizer *swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard:)];
    [swipeGesture setDirection:UISwipeGestureRecognizerDirectionDown];
    [self.view addGestureRecognizer:swipeGesture];
    [swipeGesture release];
    
    swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(showKeyboard:)];
    [swipeGesture setDirection:UISwipeGestureRecognizerDirectionUp];
    [self.view addGestureRecognizer:swipeGesture];
    [swipeGesture release];

    CGRect textBarFrame = CGRectMake(0, frame.size.height, frame.size.width, 44);
    _textBarView = [[UIView alloc] initWithFrame:textBarFrame];
    [_textBarView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    _textBarView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"BlackToolbarPattern"]];

    _textField = [[[UITextField alloc] initWithFrame:CGRectMake(6, 6, frame.size.width-12, 44-12)] autorelease];
    _textField.leftViewMode = UITextFieldViewModeAlways;
    _textField.rightViewMode = UITextFieldViewModeAlways;
    _textField.borderStyle = UITextBorderStyleRoundedRect;
    _textField.textColor = [UIColor blackColor];
    _textField.font = [UIFont systemFontOfSize:17.0];
    _textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _textField.returnKeyType = UIReturnKeySend;
    [_textField setDelegate:self];
    [_textBarView addSubview:_textField];
    [self.view addSubview:_textBarView];
    
    [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
}

- (void) setReceiverName:(NSString *)receiver andImage:(NSString *)imageName {
    MUMessageReceiverButton *receiverView = [[[MUMessageReceiverButton alloc] initWithText:receiver] autorelease];
    [receiverView addTarget:self action:@selector(showRecipientPicker:) forControlEvents:UIControlEventTouchUpInside];
    _textField.leftView = receiverView;

    UIImageView *imgView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:imageName]] autorelease];
    _textField.rightView = imgView;
    _textField.rightViewMode = UITextFieldViewModeAlways;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_textField resignFirstResponder];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([[UIMenuController sharedMenuController] isMenuVisible]) {
        [[UIMenuController sharedMenuController] setMenuVisible:NO animated:YES];
    }
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_messages count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"MUMessageViewCell";
    MUMessageBubbleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[MUMessageBubbleTableViewCell alloc] initWithReuseIdentifier:CellIdentifier];
    }

    MUTextMessage *txtMsg = [_messages objectAtIndex:[indexPath row]];
    [cell setHeading:[txtMsg heading]];
    [cell setMessage:[txtMsg message]];
    [cell setDate:[txtMsg date]];
    [cell setRightSide:[txtMsg isSentBySelf]];
    [cell setDelegate:self];
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    MUTextMessage *txtMsg = [_messages objectAtIndex:[indexPath row]];
    return [MUMessageBubbleTableViewCell heightForCellWithHeading:[txtMsg heading] message:[txtMsg message] date:[txtMsg date]];
}

#pragma mark - UIKeyboard notifications, UIView gesture recognizer

- (void) showKeyboard:(id)sender {
    [_textField becomeFirstResponder];
}

- (void) hideKeyboard:(id)sender {
    [_textField resignFirstResponder];
}

- (void) keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    
    NSValue *val = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval t;
    [val getValue:&t];
    
    val = [userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationCurve c;
    [val getValue:&c];
    
    val = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect r;
    [val getValue:&r];
    r = [self.view convertRect:r fromView:nil];

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:t];
    [UIView setAnimationCurve:c];
    _tableView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, r.size.height, 0.0f);
    _tableView.scrollIndicatorInsets = _tableView.contentInset;
    _textBarView.frame = CGRectMake(0, r.origin.y-44.0f, _tableView.frame.size.width, 44.0f);
    [UIView commitAnimations];

    if ([_messages count] > 0)
        [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[_messages count]-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void) keyboardWillHide:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    
    NSValue *val = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval t;
    [val getValue:&t];
    
    val = [userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationCurve c;
    [val getValue:&c];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:t];
    [UIView setAnimationCurve:c];
    _tableView.contentInset = UIEdgeInsetsZero;
    _tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
    _textBarView.frame = CGRectMake(0, _tableView.frame.size.height, _tableView.frame.size.width, 44.0f);
    [UIView commitAnimations];

    if ([_messages count] > 0)
        [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[_messages count]-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    if ([[textField text] length] == 0)
        return NO;


    NSString *originalStr = [textField text];
    NSString *str = [originalStr stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    str = [str stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];    
    NSString *htmlText = [NSString stringWithFormat:@"<p>%@</p>", str];
    
    NSString *destName = nil;
    if (_tree == nil && _channel == nil && _user == nil) {
        [_model sendTextMessage:[MKTextMessage messageWithHTML:htmlText] toChannel:[[_model connectedUser] channel]];
        destName = [[[_model connectedUser] channel] channelName];
    } else if (_user != nil) {
        [_model sendTextMessage:[MKTextMessage messageWithHTML:htmlText] toUser:_user];
        destName = [_user userName];
    } else if (_channel != nil) {
        [_model sendTextMessage:[MKTextMessage messageWithHTML:htmlText] toChannel:_channel];
        destName = [_channel channelName];
    } else if (_tree != nil) {
        [_model sendTextMessage:[MKTextMessage messageWithHTML:htmlText] toTree:_tree];
        destName = [_tree channelName];
    }

    [_messages addObject:[MUTextMessage textMessageWithHeading:[NSString stringWithFormat:@"To %@", destName] andMessage:originalStr isSentBySelf:YES]];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[_messages count]-1 inSection:0];
    [_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [_tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];

    [textField setText:nil];

     return YES;
}

#pragma mark - Actions

- (void) showRecipientPicker:(id)sender {
    MUMessageRecipientViewController *recipientViewController = [[MUMessageRecipientViewController alloc] initWithServerModel:_model];
    [recipientViewController setDelegate:self];
    UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:recipientViewController];
    [recipientViewController release];

    [self presentModalViewController:navCtrl animated:YES];
    [navCtrl release];
}

#pragma mark - MUMessageBubbleTableViewCellDelegate

- (void) messageBubbleTableViewCellRequestedCopy:(MUMessageBubbleTableViewCell *)cell {
    NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
    MUTextMessage *txtMsg = [_messages objectAtIndex:[indexPath row]];
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [pasteboard setValue:[txtMsg message] forPasteboardType:(NSString *) kUTTypeUTF8PlainText];
}

- (void) messageBubbleTableViewCellRequestedDeletion:(MUMessageBubbleTableViewCell *)cell {
    NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
    [_messages removeObjectAtIndex:[indexPath row]];
    [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - MUMessageRecipientTableViewControllerDelegate

- (void) messageRecipientViewController:(MUMessageRecipientViewController *)viewCtrlr didSelectChannel:(MKChannel *)channel {
    _tree = nil;
    _channel = channel;
    _user = nil;
    
    [self setReceiverName:[channel channelName] andImage:@"channelmsg"];
}

- (void) messageRecipientViewController:(MUMessageRecipientViewController *)viewCtrlr didSelectUser:(MKUser *)user {
    _tree = nil;
    _channel = nil;
    _user = user;
    
    [self setReceiverName:[user userName] andImage:@"usermsg"];
}

- (void) messageRecipientViewControllerDidSelectCurrentChannel:(MUMessageRecipientViewController *)viewCtrlr {
    _tree = nil;
    _channel = nil;
    _user = nil;

    [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
}

#pragma mark - MKServerModel delegate

- (void) serverModel:(MKServerModel *)model userMoved:(MKUser *)user toChannel:(MKChannel *)chan fromChannel:(MKChannel *)prevChan byUser:(MKUser *)mover {
    if (user == [_model connectedUser]) {
        // Are we in 'send to default channel mode'?
        if (_user == nil && _channel == nil && _tree == nil) {
            [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
        }
    }
}

- (void) serverModel:(MKServerModel *)model userLeft:(MKUser *)user {
    if (user == _user) {
        _user = nil;
    }

    [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
}

- (void) serverModel:(MKServerModel *)model channelRenamed:(MKChannel *)channel {
    if (channel == _tree) {
        [self setReceiverName:[channel channelName] andImage:@"channelmsg"];
    } else if (channel == _channel) {
         [self setReceiverName:[channel channelName] andImage:@"channelmsg"];
    } else if (_channel == nil && _tree == nil && _user == nil && [[_model connectedUser] channel] == channel) {
        [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
    }
}

- (void) serverModel:(MKServerModel *)model channelRemoved:(MKChannel *)channel {
    if (channel == _tree) {
        _tree = nil;
        [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
    } else if (channel == _channel) {
        _channel = nil;
        [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
    }
}

- (void) serverModel:(MKServerModel *)model textMessageReceived:(MKTextMessage *)msg fromUser:(MKUser *)user {
    NSString *plainMsg = [msg plainTextString];
    if ([[msg embeddedImages] count] > 0) {
        plainMsg = [NSString stringWithFormat:@"%@ (Message contained images that could not be shown)", [msg plainTextString]];
    }
    plainMsg = [plainMsg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [_messages addObject:[MUTextMessage textMessageWithHeading:[NSString stringWithFormat:@"From %@", [user userName]] andMessage:plainMsg isSentBySelf:NO]];

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[_messages count]-1 inSection:0];
    [_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    if (![_tableView isDragging] && ![[UIMenuController sharedMenuController] isMenuVisible]) {
        [_tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

@end
