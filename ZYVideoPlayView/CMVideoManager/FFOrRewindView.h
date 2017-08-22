//
//  FFOrRewindView.h
//  ZYVideoPlayView
//
//  Created by 王智垚 on 2017/8/21.
//  Copyright © 2017年 王智垚. All rights reserved.
//  快进快退View

#import <UIKit/UIKit.h>

@interface FFOrRewindView : UIView
/** 快进/快退图标 **/
@property (nonatomic, strong) UIImageView *stateImageView;
/** 提示标题 **/
@property (nonatomic, strong) UILabel *timeLabel;
@end
