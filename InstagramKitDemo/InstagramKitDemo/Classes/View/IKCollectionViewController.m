//
//    Copyright (c) 2013 Shyam Bhat
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy of
//    this software and associated documentation files (the "Software"), to deal in
//    the Software without restriction, including without limitation the rights to
//    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//    the Software, and to permit persons to whom the Software is furnished to do so,
//    subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "IKCollectionViewController.h"
#import "InstagramKit.h"
#import "UIImageView+AFNetworking.h"
#import "IKCell.h"
#import "InstagramMedia.h"
#import "InstagramUser.h"
#import "IKLoginViewController.h"
#import "IKMediaViewController.h"

#import <SVPullToRefresh.h>

const bool infiniteScrollingMode = YES;

@interface IKCollectionViewController ()
{
    NSMutableArray *mediaArray;
    __weak IBOutlet UITextField *textField;
}
@property (nonatomic, strong) InstagramPaginationInfo *currentPaginationInfo;
@property bool isLoadingInfinitely;
@end

@implementation IKCollectionViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        mediaArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]) {
        self.automaticallyAdjustsScrollViewInsets = NO;
		
        UIEdgeInsets insets = self.collectionView.contentInset;
		
		insets.top = self.navigationController.navigationBar.bounds.size.height +
		[UIApplication sharedApplication].statusBarFrame.size.height;
        self.collectionView.contentInset = insets;
        self.collectionView.scrollIndicatorInsets = insets;
    }
	
	__weak typeof(self) weakSelf = self;
	__weak typeof(mediaArray) weakMediaArray = mediaArray;
	[self.collectionView addInfiniteScrollingWithActionHandler:^{
		[weakSelf loadMedia];
	}];
	
	[self.collectionView addPullToRefreshWithActionHandler:^{
		weakSelf.collectionView.showsInfiniteScrolling = NO;
		[weakMediaArray removeAllObjects];
		[weakSelf.collectionView reloadData];
		[weakSelf reloadMedia];
		[weakSelf.collectionView.pullToRefreshView stopAnimating];
		[weakSelf.collectionView.infiniteScrollingView stopAnimating];
	}];
	
	[self loadMedia];
}

- (IBAction)reloadMedia
{
	//scroll to top
	if([self.collectionView numberOfItemsInSection:0] > 1)
		[self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
	
    self.currentPaginationInfo = nil;
    if (mediaArray) {
        [mediaArray removeAllObjects];
    }

    [self loadMedia];
}

- (void)loadMedia
{
    [textField resignFirstResponder];
    textField.text = @"";

    InstagramEngine *sharedEngine = [InstagramEngine sharedEngine];
    
    if (sharedEngine.accessToken)
    {
        [self testLoadSelfFeed];
//        [self testLoadSelfLikedMedia];
//        [self getSelfUserDetails];
    }
    else
    {
        [self testLoadPopularMedia];
    }
}

- (IBAction)searchMedia
{
    self.currentPaginationInfo = nil;
    if (mediaArray) {
        [mediaArray removeAllObjects];
    }
    [textField resignFirstResponder];

    if ([textField.text length]) {
        [self testGetMediaFromTag:textField.text];
//        [self testSearchUsersWithString:textField.text];
    }
}


- (void)testLoadPopularMedia
{
	if(_isLoadingInfinitely)
	return;
	_isLoadingInfinitely = YES;
	
    [[InstagramEngine sharedEngine] getPopularMediaWithSuccess:^(NSArray *media, InstagramPaginationInfo *paginationInfo) {
		if(!infiniteScrollingMode)
			[mediaArray removeAllObjects];
        [mediaArray addObjectsFromArray:media];
        [self reloadData];
		_isLoadingInfinitely = NO;
		self.collectionView.showsInfiniteScrolling = YES;
    } failure:^(NSError *error) {
        NSLog(@"Load Popular Media Failed");
    }];
}

- (void)getSelfUserDetails
{
    [[InstagramEngine sharedEngine] getSelfUserDetailsWithSuccess:^(InstagramUser *userDetail) {
        NSLog(@"%@",userDetail);
    } failure:^(NSError *error) {
        
    }];
}


- (void)testLoadSelfFeed
{
	if(_isLoadingInfinitely)
		return;
	_isLoadingInfinitely = YES;
	
    [[InstagramEngine sharedEngine] getSelfFeedWithCount:18 maxId:self.currentPaginationInfo.nextMaxId success:^(NSArray *media, InstagramPaginationInfo *paginationInfo) {
        self.currentPaginationInfo = paginationInfo;
        
		[mediaArray addObjectsFromArray:media];
        [self reloadData];
		_isLoadingInfinitely = NO;
		self.collectionView.showsInfiniteScrolling = YES;
		[self.collectionView.infiniteScrollingView stopAnimating];
    } failure:^(NSError *error) {
        NSLog(@"Request Self Feed Failed");
    }];
}


- (void)testLoadSelfLikedMedia
{
    [[InstagramEngine sharedEngine] getMediaLikedBySelfWithCount:15 maxId:self.currentPaginationInfo.nextMaxId success:^(NSArray *media, InstagramPaginationInfo *paginationInfo) {
        self.currentPaginationInfo = paginationInfo;
        
        [mediaArray addObjectsFromArray:media];
        
        [self reloadData];
    } failure:^(NSError *error) {
        NSLog(@"Request Self Liked Media Failed");
        
    }];
}


- (void)testSearchUsersWithString:(NSString *)string
{
    [[InstagramEngine sharedEngine] searchUsersWithString:string withSuccess:^(NSArray *users, InstagramPaginationInfo *paginationInfo) {
        NSLog(@"%ld users found", (long)users.count);
    } failure:^(NSError *error) {
        NSLog(@"user search failed");
    }];
}

- (void)testGetMediaFromTag:(NSString *)tag
{
    [[InstagramEngine sharedEngine] getMediaWithTagName:tag count:15 maxId:self.currentPaginationInfo.nextMaxId withSuccess:^(NSArray *media, InstagramPaginationInfo *paginationInfo) {
        self.currentPaginationInfo = paginationInfo;
        [mediaArray addObjectsFromArray:media];
        [self reloadData];
        
    } failure:^(NSError *error) {
        NSLog(@"Search Media Failed");
    }];
}

- (void)testLoadMediaForUser:(InstagramUser *)user
{
    [[InstagramEngine sharedEngine] getMediaForUser:user.Id count:15 maxId:self.currentPaginationInfo.nextMaxId withSuccess:^(NSArray *feed, InstagramPaginationInfo *paginationInfo) {

        if (paginationInfo) {
            self.currentPaginationInfo = paginationInfo;
        }
        
        [mediaArray addObjectsFromArray:feed];
        [self reloadData];
        
    } failure:^(NSError *error) {
        NSLog(@"Loading User media failed");
    }];
}

- (void)testPaginationRequest:(InstagramPaginationInfo *)pInfo
{
    [[InstagramEngine sharedEngine] getPaginatedItemsForInfo:self.currentPaginationInfo withSuccess:^(NSArray *media, InstagramPaginationInfo *paginationInfo) {
        NSLog(@"%ld more media in Pagination",(unsigned long)media.count);
        self.currentPaginationInfo = paginationInfo;
        [mediaArray addObjectsFromArray:media];
        [self reloadData];
        
    } failure:^(NSError *error) {
        NSLog(@"Pagination Failed");
    }];
}

- (void)reloadData
{
    [self.collectionView reloadData];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"segue.media.detail"]) {
        IKMediaViewController *mvc = (IKMediaViewController *)segue.destinationViewController;
        NSIndexPath *selectedIndexPath = [self.collectionView indexPathsForSelectedItems][0];
        InstagramMedia *media = mediaArray[selectedIndexPath.item];
        mvc.media = media;
    }
    if ([segue.identifier isEqualToString:@"segue.login"]) {
        UINavigationController *loginNavigationVC = (UINavigationController *)segue.destinationViewController;
        IKLoginViewController *loginVc = loginNavigationVC.viewControllers[0];
        loginVc.collectionViewController = self;
    }
}

#pragma mark - UICollectionViewDelegate -

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	//I prefer the last row to have three items
	if(mediaArray.count > 2)
		return mediaArray.count - (mediaArray.count % 3);
	else
		return mediaArray.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    IKCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"CPCELL" forIndexPath:indexPath];
    
    if (mediaArray.count >= indexPath.row+1) {
        InstagramMedia *media = mediaArray[indexPath.row];
        [cell.imageView setImageWithURL:media.thumbnailURL];
    }
    else
        [cell.imageView setImage:nil];
    return cell;

}


-(void)scrollViewDidScroll:(UIScrollView *)scrollView{

	//Must be pulling to refresh. Ignore this
	if(scrollView.contentOffset.y < -64)
		return;
	
	int diff = abs(abs(scrollView.contentOffset.y - scrollView.contentSize.height) - 568);
	if(abs(diff - 60) < 10){
//		NSLog(@"triggered Refresh");
		[self.collectionView triggerInfiniteScrolling];
	}
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
//    InstagramMedia *media = mediaArray[indexPath.row];
//    [self testLoadMediaForUser:media.user];
    
    if (self.currentPaginationInfo)
    {
//  Paginate on navigating to detail
//either
//        [self loadMedia];
//or
//        [self testPaginationRequest:self.currentPaginationInfo];
    }
}

#pragma mark - UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)tField
{
    if (tField.text.length) {
        [self searchMedia];
    }
    [tField resignFirstResponder];

    return YES;
}

@end
