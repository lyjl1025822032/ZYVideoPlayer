//
//  FFOrRewindView.m
//  ZYVideoPlayView
//
//  Created by 王智垚 on 2017/8/21.
//  Copyright © 2017年 王智垚. All rights reserved.
//

#import "FFOrRewindView.h"

@implementation FFOrRewindView
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        if (!_stateImageView) {
            _stateImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.center.x-43/2, 12, 43, 25)];
            _stateImageView.contentMode = UIViewContentModeScaleAspectFit;
            [_stateImageView setImage:kVideoViewPicName(@"icon_progress_l")];
            [self addSubview:_stateImageView];
        }
        
        if (!_timeLabel) {
            _timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.center.x-118/2, CGRectGetMaxY(self.stateImageView.frame), 118, 20)];
            _timeLabel.font = [UIFont systemFontOfSize:13];
            _timeLabel.textColor = [UIColor whiteColor];
            _timeLabel.textAlignment = NSTextAlignmentCenter;
            [self addSubview:_timeLabel];
        }
    }
    return self;
}
@end
