//
//  AudioEngine.h
//  AVFoundation Sounds
//
//  Created by Michael Fenty on 2015-08-22.
//  Copyright (c) 2015 __MIKE FENTY__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioEngine : NSObject

+(instancetype)sharedData;
-(void) playSfxFile:(NSString*)file;
-(void) playMusicFile:(NSString*)file;
-(void) pauseMusic:(NSString*)file;
-(void) unpauseMusic:(NSString*)file;
-(void) stopMusicFile:(NSString*)file;
//-(void) setVolumePercentages;

@end
