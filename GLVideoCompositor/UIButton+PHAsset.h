//
//  UIButton+PHAsset.h
//  GLVideoCompositor
//
//  Created by Mikhail Grushin on 04/04/15.
//  Copyright (c) 2015 Mikhail Grushin. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PHAsset;

@interface UIButton (PHAsset)

- (void)configureImageWithPHAsset:(PHAsset *)asset;

@end
