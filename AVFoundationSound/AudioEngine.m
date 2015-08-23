//
//  AudioEngine.m
//  AVFoundation Sounds
//
//  Created by Michael Fenty on 2015-08-22.
//  Copyright (c) 2015 __MIKE FENTY__. All rights reserved.
//

#import "AudioEngine.h"
#import <AVFoundation/AVFoundation.h>
//#import "GameData.h"

@interface AudioEngine()

@property AVAudioEngine *engine;
@property AVAudioMixerNode *mixer;

@property NSMutableDictionary *musicDict;
@property NSMutableDictionary *sfxDict;

@property NSString *audioInfoPList;

@property float musicVolumePercent;
@property float sfxVolumePercent;
@property float fadeVolume;
@property float timerCount;

@end

@implementation AudioEngine

int const FADE_ITERATIONS = 10;
static NSString * const MUSIC_PLAYER = @"player";
static NSString * const MUSIC_BUFFERS = @"buffers";
static NSString * const MUSIC_FRAME_POSITIONS = @"framePositions";
static NSString * const MUSIC_SAMPLE_RATE = @"sampleRate";

static NSString * const SFX_BUFFER = @"buffer";
static NSString * const SFX_PLAYER = @"player";

+(instancetype) sharedData {
	static AudioEngine *sharedInstance = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance startEngine];
	});
	
	return sharedInstance;
}

-(instancetype) init {
	if (self = [super init]) {
		_engine = [[AVAudioEngine alloc] init];
		_mixer = [_engine mainMixerNode];
		
		_audioInfoPList = [[NSBundle mainBundle] pathForResource:@"AudioInfo" ofType:@"plist"];
		
		//[self setVolumePercentages];
		[self initMusic];
		[self initSfx];
	}
	return self;
}

-(void) initMusic {
	_musicDict = [NSMutableDictionary dictionary];
	
	_audioInfoPList = [[NSBundle mainBundle] pathForResource: @"AudioInfo" ofType: @"plist"];
	NSDictionary *audioInfoData = [NSDictionary dictionaryWithContentsOfFile:_audioInfoPList];
	
	for (NSString *musicFileName in audioInfoData[@"music"]) {
		[self loadMusicIntoBuffer:musicFileName];
		AVAudioPlayerNode *player = [[AVAudioPlayerNode alloc] init];
		[_engine attachNode:player];
		
		AVAudioPCMBuffer *buffer = [[_musicDict[musicFileName] objectForKey:MUSIC_BUFFERS] objectAtIndex:0];
		[_engine connect:player to:_mixer format:buffer.format];
		[_musicDict[musicFileName] setObject:player forKey:@"player"];
	}
}

-(void) loadMusicIntoBuffer:(NSString *)filename
{
	NSURL *audioFileURL = [[NSBundle mainBundle] URLForResource:filename withExtension:@"aif"];
	//NSURL *audioFileURL = [NSURL URLWithString:[[NSBundle mainBundle] pathForResource:filename ofType:@"aif"]];
	NSAssert(audioFileURL, @"Error creating URL to audio file");
	NSError *error = nil;
	AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:audioFileURL commonFormat:AVAudioPCMFormatFloat32 interleaved:NO error:&error];
	NSAssert(audioFile != nil, @"Error creating audioFile, %@", error.localizedDescription);
	
	AVAudioFramePosition fileLength = audioFile.length;
	float sampleRate = audioFile.fileFormat.sampleRate;
	[_musicDict setObject:[NSMutableDictionary dictionary] forKey:filename];
	[_musicDict[filename] setObject:[NSNumber numberWithDouble:sampleRate] forKey:MUSIC_SAMPLE_RATE];
	
	NSMutableArray *buffers = [NSMutableArray array];
	NSMutableArray *framePositions = [NSMutableArray array];
	
	const AVAudioFrameCount kBufferFrameCapacity = 1024 * 1024L;
	//AVAudioPCMBuffer *readBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFile.processingFormat frameCapacity:kBufferFrameCapacity];
	
	while (audioFile.framePosition < fileLength) {
		[framePositions addObject:[NSNumber numberWithLongLong:audioFile.framePosition]];
		AVAudioPCMBuffer *readBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFile.processingFormat frameCapacity:kBufferFrameCapacity];
		if (![audioFile readIntoBuffer:readBuffer error:&error]) {
			NSLog(@"failed to read audio file: %@", error);
			return;
		}
		if (readBuffer.frameLength == 0) {
			break;
		}
		[buffers addObject:readBuffer];
	}
	
	[_musicDict[filename] setObject:buffers forKey:MUSIC_BUFFERS];
	[_musicDict[filename] setObject:framePositions forKey:MUSIC_FRAME_POSITIONS];
}

-(void) initSfx {
	_sfxDict = [NSMutableDictionary dictionary];
	
	//NSString *audioInfoPList = [[NSBundle mainBundle] pathForResource: @"AudioInfo" ofType: @"plist"];
	NSDictionary *audioInfoData = [NSDictionary dictionaryWithContentsOfFile:_audioInfoPList];
	
	for (NSString *sfxFileName in audioInfoData[@"sfx"]) {
		AVAudioPlayerNode *player = [[AVAudioPlayerNode alloc] init];
		[_engine attachNode:player];
		
		[self loadSoundIntoBuffer:sfxFileName];
		AVAudioPCMBuffer *buffer = [_sfxDict[sfxFileName] objectForKey:SFX_BUFFER];
		[_engine connect:player to:_mixer format:buffer.format];
		[_sfxDict[sfxFileName] setObject:player forKey:SFX_PLAYER];
	}
}

//WARNING: make sure that the sound fx file is small otherwise the archived version of the app will crash because the buffer ran out of space
-(void) loadSoundIntoBuffer:(NSString *)filename
{
	NSURL *audioFileURL = [NSURL URLWithString:[[NSBundle mainBundle] pathForResource:filename ofType:@"mp3"]];
	NSAssert(audioFileURL, @"Error creating URL to audio file");
	NSError *error = nil;
	AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:audioFileURL commonFormat:AVAudioPCMFormatFloat32 interleaved:NO error:&error];
	NSAssert(audioFile != nil, @"Error creating audioFile, %@", error.localizedDescription);
	
	AVAudioPCMBuffer *readBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFile.processingFormat frameCapacity:(AVAudioFrameCount)audioFile.length];
	NSAssert([audioFile readIntoBuffer:readBuffer error:&error], @"Error reading file into buffer, %@", error.localizedDescription);
	
	[_sfxDict setObject:[NSMutableDictionary dictionary] forKey:filename];
	[_sfxDict[filename] setObject:readBuffer forKey:SFX_BUFFER];
}

-(void)startEngine {
	[_engine startAndReturnError:nil];
}

-(void) playSfxFile:(NSString*)file {
	AVAudioPlayerNode *player = [_sfxDict[file] objectForKey:@"player"];	
	AVAudioPCMBuffer *buffer = [_sfxDict[file] objectForKey:SFX_BUFFER];
	[player scheduleBuffer:buffer atTime:nil options:AVAudioPlayerNodeBufferInterrupts completionHandler:nil];
	[player setVolume:1.0];
	//[player setVolume:_sfxVolumePercent];
	[player play];
}

-(void) playMusicFile:(NSString*)file {
	NSArray *buffers = [_musicDict[file] objectForKey:MUSIC_BUFFERS];
	
	double sampleRate = [[_musicDict[file] objectForKey:MUSIC_SAMPLE_RATE] doubleValue];
	
	AVAudioPlayerNode *player = [_musicDict[file] objectForKey:MUSIC_PLAYER];
	for (int i = 0; i < [buffers count]; i++) {
		long long framePosition = [[[_musicDict[file] objectForKey:MUSIC_FRAME_POSITIONS] objectAtIndex:i] longLongValue];
		AVAudioTime *time = [AVAudioTime timeWithSampleTime:framePosition atRate:sampleRate];
		
		AVAudioPCMBuffer *buffer  = [buffers objectAtIndex:i];
		[player scheduleBuffer:buffer atTime:time options:AVAudioPlayerNodeBufferInterruptsAtLoop completionHandler:^{
			if (i == [buffers count] - 1) {
				[player stop];
				[self playMusicFile:file];
				NSLog(@"repeating");
			}
		}];
		[player setVolume:1];
		[player play];
	}
	
	//[player setVolume:_musicVolumePercent]; ///UNCOMMENT THIS
	
}

-(void) stopMusicFile:(NSString*)file {
	AVAudioPlayerNode *player = [_musicDict[file] objectForKey:MUSIC_PLAYER];
	
	if ([player isPlaying]) {
		_timerCount = FADE_ITERATIONS;
		_fadeVolume = _musicVolumePercent;
		[self fadeOutMusicForPlayer:player];
	}
}

-(void) pauseMusic:(NSString*)file {
	AVAudioPlayerNode *player = [_musicDict[file] objectForKey:MUSIC_PLAYER];
	if ([player isPlaying]) {
		[player pause];
	}
}

-(void) unpauseMusic:(NSString*)file {
	AVAudioPlayerNode *player = [_musicDict[file] objectForKey:MUSIC_PLAYER];
	[player play];
}

-(void) fadeOutMusicForPlayer:(AVAudioPlayerNode*)player {
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleTimer:) userInfo:player repeats:YES];
}

-(void) handleTimer:(NSTimer*)timer {
	AVAudioPlayerNode *player = (AVAudioPlayerNode*)timer.userInfo;
	if (_timerCount > 0) {
		_timerCount--;
		AVAudioPlayerNode *player = (AVAudioPlayerNode*)timer.userInfo;
		_fadeVolume = _musicVolumePercent * (_timerCount / FADE_ITERATIONS);
		[player setVolume:_fadeVolume];
	}
	else {
		[player stop];
		[player setVolume:_musicVolumePercent];
		[timer invalidate];
	}
}

/*-(void) setVolumePercentages {
 NSString *musicVolumeString = [[GameData sharedGameData].settings objectForKey:@"musicVolume"];
 _musicVolumePercent = [[[musicVolumeString componentsSeparatedByCharactersInSet:
 [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
 componentsJoinedByString:@""] floatValue] / 100;
 NSString *sfxVolumeString = [[GameData sharedGameData].settings objectForKey:@"sfxVolume"];
 _sfxVolumePercent = [[[sfxVolumeString componentsSeparatedByCharactersInSet:
 [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
 componentsJoinedByString:@""] floatValue] / 100;
 
 //immediately sets music to new volume
 for (AVAudioPlayerNode *player in [_musicPlayers allValues]) {
 [player setVolume:_musicVolumePercent];
 }
 }*/

@end