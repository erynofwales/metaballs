//
//  MetaballsSaverView.m
//  MetaballsSaver
//
//  Created by Eryn Wells on 8/16/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

@import MetaballsKit;

#import "MetaballsSaverView.h"

@implementation MetaballsSaverViewX

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/30.0];
    }
    return self;
}

- (void)startAnimation
{
    [super startAnimation];
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (void)drawRect:(NSRect)rect
{
    [super drawRect:rect];
}

- (void)animateOneFrame
{
    return;
}

- (BOOL)hasConfigureSheet
{
    return NO;
}

- (NSWindow*)configureSheet
{
    return nil;
}

@end
