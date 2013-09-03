
//  Created by tashigaofei on 13/08/26.
//  Copyright (c) 2013 baidu. All rights reserved.
//

#import "MPVolumeObserver.h"


@interface MPVolumeObserver()
{
    UIView *_volumeView;
    float launchVolume;
    BOOL _isStealingVolumeButtons;
    BOOL _suspended;
}
@end

@implementation MPVolumeObserver

+(MPVolumeObserver*) sharedInstance;
{
    static MPVolumeObserver *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MPVolumeObserver alloc] init];
    });
    
    return instance;
}

-(id)init
{
    self = [super init];
    if( self ){
        _isStealingVolumeButtons = NO;
        _suspended = NO;
        CGRect frame = CGRectMake(0, -100, 0, 0);
        _volumeView = [[MPVolumeView alloc] initWithFrame:frame];
        [[UIApplication sharedApplication].keyWindow addSubview:_volumeView];
         
    }
    return self;
}

-(void)startObserveVolumeChangeEvents
{
    double delayInSeconds = 0.25;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self startObserve];
    });
}

-(void) startObserve;
{
    if(_isStealingVolumeButtons) {
        return;
    }
    
    _isStealingVolumeButtons = YES;
    AudioSessionInitialize(NULL, NULL, NULL, NULL);
    SInt32  process = kAudioSessionCategory_AmbientSound;
    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(process), &process);
    AudioSessionSetActive(YES);
    
    launchVolume = [[MPMusicPlayerController applicationMusicPlayer] volume];
    launchVolume = launchVolume == 0 ? 0.05 : launchVolume;
    launchVolume = launchVolume == 1 ? 0.95 : launchVolume;
    if (launchVolume == 0.05 || launchVolume == 0.95) {
        [[MPMusicPlayerController applicationMusicPlayer] setVolume:launchVolume];
    }
  
    if (!_suspended)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(suspendStealingVolumeButtonEvents:)
                                                     name:UIApplicationWillResignActiveNotification     // -> Inactive
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(resumeStealingVolumeButtonEvents:)
                                                     name:UIApplicationDidBecomeActiveNotification      // <- Active
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChangeNotification:)
                                                     name:@"SystemVolumeDidChange" object:nil];
    }
    

}

-(void) volumeChangeNotification:(NSNotification *) no
{
    static id sender = nil;
    if (sender == nil && no.object) {
        sender = no.object;
    }
    
    if (no.object != sender || [[no.userInfo objectForKey:@"AudioVolume"] floatValue] == launchVolume) {
        return;
    }
    
    [[MPMusicPlayerController applicationMusicPlayer] setVolume:launchVolume];
  
    if ([_delegate respondsToSelector:@selector(volumeButtonDidClick:)]) {
        [_delegate volumeButtonDidClick:self];
    }
    
//    NSLog(@"\n\n%@\n\n", no);
}


- (void)suspendObserveVolumeChangeEvents:(NSNotification *)notification
{
    if(_isStealingVolumeButtons)
    {
        _suspended = YES; // Call first!
        [self stopObserveVolumeChangeEvents];
    }
}

- (void)resumeStealingVolumeButtonEvents:(NSNotification *)notification
{
    if(_suspended)
    {
        [self startObserveVolumeChangeEvents];
        _suspended = NO; // Call last!
    }
}

-(void)stopObserveVolumeChangeEvents
{
    
    if(!_isStealingVolumeButtons){
        return;
    }
    
    if (!_suspended){
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_CurrentHardwareOutputVolume, NULL, self);
    AudioSessionSetActive(NO);

    _isStealingVolumeButtons = NO;
    
}

-(void)dealloc
{
   _suspended = NO;
    [super dealloc];
}

@end
