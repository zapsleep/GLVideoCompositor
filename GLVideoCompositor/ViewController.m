//
//  ViewController.m
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVKit/AVKit.h>

#import "UIButton+PHAsset.h"
#import "GRUVideoCompositor.h"

typedef NS_ENUM(NSUInteger, GMAVideoNumber) {
    GMAFirstVideo = 1,
    GMASecondVideo = 2
};

@interface ViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UIButton *firstVideoButton;
@property (weak, nonatomic) IBOutlet UIButton *secondVideoButton;
@property (weak, nonatomic) IBOutlet UIScrollView *transitionsScrollView;

@property (nonatomic, strong) AVAsset *firstVideoAsset;
@property (nonatomic, strong) AVAsset *secondVideoAsset;

@property (nonatomic, assign) GMAVideoNumber currentlyPickingNumber;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.navigationController.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private interface

- (void)pickVideoWithNumber:(GMAVideoNumber)videoNumber {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.mediaTypes = @[(NSString *)kUTTypeMovie];
    
    [self presentViewController:picker animated:YES completion:^{
        self.currentlyPickingNumber = videoNumber;
    }];
}

- (BOOL)loadAssetPropertiesSynchronously:(AVAsset *)asset {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    __block BOOL isLoaded = NO;
    NSArray *values = @[@"duration", @"tracks", @"composable"];
    [asset loadValuesAsynchronouslyForKeys:values completionHandler:^{
        [values enumerateObjectsUsingBlock:^(NSString *valueStr, NSUInteger idx, BOOL *stop) {
            isLoaded = YES;
            if ([asset statusOfValueForKey:valueStr error:nil] == AVKeyValueStatusFailed) {
                isLoaded = NO;
                *stop = YES;
                dispatch_semaphore_signal(semaphore);
            }
            
            dispatch_semaphore_signal(semaphore);
        }];
    }];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10.f * NSEC_PER_SEC));
    return isLoaded;
}

#pragma mark - Actions

- (IBAction)playAction:(id)sender {
    if (!(self.firstVideoAsset && self.secondVideoAsset)) {
        [[[UIAlertView alloc] initWithTitle:@"Need more assets"
                                    message:@"You must first pick two videos"
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    } else {
        AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
        GRUVideoCompositor *compositor = [[GRUVideoCompositor alloc] init];
        AVPlayerItem *playerItem = [compositor compileCompositionWithAssets:@[self.firstVideoAsset, self.secondVideoAsset]];
        AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
        playerVC.player = player;
        
        [self presentViewController:playerVC animated:YES completion:nil];
    }
}

- (IBAction)chooseFirstVideo:(id)sender {
    if (self.firstVideoAsset) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Choose video"
                                                        message:@"Do you want to pick other first video?"
                                                       delegate:self
                                              cancelButtonTitle:@"No"
                                              otherButtonTitles:@"Yes", nil];
        alert.tag = GMAFirstVideo;
        [alert show];
    } else {
        [self pickVideoWithNumber:GMAFirstVideo];
    }
}

- (IBAction)chooseSecondVideo:(id)sender {
    if (self.secondVideoAsset) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Choose video"
                                                        message:@"Do you want to pick other second video?"
                                                       delegate:self
                                              cancelButtonTitle:@"No"
                                              otherButtonTitles:@"Yes", nil];
        alert.tag = GMASecondVideo;
        [alert show];
    } else {
        [self pickVideoWithNumber:GMASecondVideo];
    }
}

#pragma mark - Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != alertView.cancelButtonIndex) {
        [self pickVideoWithNumber:alertView.tag];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSURL *url = info[UIImagePickerControllerReferenceURL];
    
    PHFetchResult *result = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil];
    PHAsset *ph_asset = [result firstObject];
    [[PHImageManager defaultManager] requestAVAssetForVideo:ph_asset options:nil resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
        if (asset && [self loadAssetPropertiesSynchronously:asset]) {
            if (self.currentlyPickingNumber == GMAFirstVideo) {
                self.firstVideoAsset = asset;
                [self.firstVideoButton configureImageWithPHAsset:ph_asset];
            } else if (self.currentlyPickingNumber == GMASecondVideo) {
                self.secondVideoAsset = asset;
                [self.secondVideoButton configureImageWithPHAsset:ph_asset];
            }
        }
        
        self.currentlyPickingNumber = 0;
    }];
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (NSUInteger)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController {
    return UIInterfaceOrientationMaskPortrait;
}

@end
