//
//  GameScene.m
//  AVFoundationSound
//
//  Created by Michael Fenty on 2015-08-23.
//  Copyright (c) 2015 __MIKE FENTY__. All rights reserved.
//

#import "GameScene.h"
#import "AudioEngine.h"

@implementation GameScene

-(void)didMoveToView:(SKView *)view {
	[[AudioEngine sharedData] playSfxFile:@"gamestart"];
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
}

@end
