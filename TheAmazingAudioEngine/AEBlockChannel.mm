//
//  AEBlockChannel.m
//  TheAmazingAudioEngine
//
//  Created by Michael Tyson on 20/12/2012.
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "AEBlockChannel.h"
#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <atomic>

@interface AEBlockChannel ()
@property (nonatomic, copy) AEBlockChannelBlock block;
@end

@implementation AEBlockChannel {
    std::atomic<float> _average;
    std::atomic<bool> _resetMetering;
    int _accumulatorCount;
    float _accumulator;
}
@synthesize block = _block;

- (id)initWithBlock:(AEBlockChannelBlock)block {
    
    if ( !(self = [super init]) ) self = nil;
    self.volume = 1.0;
    self.pan = 0.0;
    self.block = block;
    self.channelIsMuted = NO;
    self.channelIsPlaying = YES;
    _average = -500;
    _resetMetering = NO;
    _accumulatorCount = 0;
    _accumulator = 0;
    return self;
}

+ (AEBlockChannel*)channelWithBlock:(AEBlockChannelBlock)block {
    
    return [[AEBlockChannel alloc] initWithBlock:block];
}


-(AEAudioRenderCallback)renderCallback {
    
    return renderCallback;
}

static OSStatus renderCallback(__unsafe_unretained AEBlockChannel *channel,
                               __unsafe_unretained AEAudioController *audioController,
                               const AudioTimeStamp     *time,
                               UInt32                    frames,
                               AudioBufferList          *audio) {
    
    //
    // render audio
    //
    channel->_block(time, frames, audio);
    
    //
    // metering
    //
    if (channel->_resetMetering) {
        channel->_accumulatorCount =
        channel->_accumulator = 0;
        channel->_resetMetering = false;
    }
    for (int i = 0; i < audio->mNumberBuffers; i++) {
        float avg = 0.0;
        vDSP_meamgv((float*)audio->mBuffers[i].mData, 1, &avg, frames);
        channel->_accumulator += avg;
        channel->_accumulatorCount++;
    }
    channel->_average = channel->_accumulator / (double)channel->_accumulatorCount;
    
    return noErr;
}


- (float) averagePowerLevel {
    
    _resetMetering = true;
    /*float result = (20.0f*log10f(_average));
    NSLog(@"%@", @(result));*/
    return (20.0f*log10f(_average));
}


- (float) normalizedAveragePowerLevel {
    
    float average = [self averagePowerLevel];
    float result;
    double range = 80; // 0 -> -80 db; 1 -> 0 dB
    result = MAX(0,(range+average)/range);
    return result*_volume;
}

@end
