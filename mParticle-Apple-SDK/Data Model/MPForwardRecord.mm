//
//  MPForwardRecord.mm
//
//  Copyright 2016 mParticle, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "MPForwardRecord.h"
#import "MPIConstants.h"
#import "MPILogger.h"
#import "MPKitFilter.h"
#include "EventTypeName.h"
#include "MessageTypeName.h"
#import "MPEvent.h"
#import "MPCommerceEvent.h"
#import "MPCommerceEvent+Dictionary.h"
#import "MPEventProjection.h"
#import "MPKitExecStatus.h"

NSString *const kMPFRModuleId = @"mid";
NSString *const kMPFRProjections = @"proj";
NSString *const kMPFRProjectionId = @"pid";
NSString *const kMPFRProjectionName = @"name";
NSString *const kMPFRPushRegistrationState = @"r";
NSString *const kMPFROptOutState = @"s";

@implementation MPForwardRecord

- (instancetype)initWithId:(int64_t)forwardRecordId data:(NSData *)data {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _forwardRecordId = forwardRecordId;
    
    if (!MPIsNull(data)) {
        NSError *error = nil;
        NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        
        if (!error) {
            _dataDictionary = [NSMutableDictionary dictionaryWithDictionary:jsonDictionary];
        } else {
            MPILogError(@"Error deserializing the data into a dictionary representation: %@", [error localizedDescription]);
        }
    }
    
    return self;
}

- (instancetype)initWithMessageType:(MPMessageType)messageType execStatus:(MPKitExecStatus *)execStatus {
    return [self initWithMessageType:messageType execStatus:execStatus kitFilter:nil originalEvent:nil];
}

- (instancetype)initWithMessageType:(MPMessageType)messageType execStatus:(MPKitExecStatus *)execStatus stateFlag:(BOOL)stateFlag {
    self = [self initWithMessageType:messageType execStatus:execStatus kitFilter:nil originalEvent:nil];
    
    if (messageType == MPMessageTypePushRegistration) {
        _dataDictionary[kMPFRPushRegistrationState] = @(stateFlag);
    } else if (messageType == MPMessageTypeOptOut) {
        _dataDictionary[kMPFROptOutState] = @(stateFlag);
    }
    
    return self;
}

- (instancetype)initWithMessageType:(MPMessageType)messageType execStatus:(MPKitExecStatus *)execStatus kitFilter:(MPKitFilter *)kitFilter originalEvent:(id)originalEvent {
    self = [super init];
    
    BOOL validMessageType = messageType > MPMessageTypeUnknown && messageType <= MPMessageTypeCommerceEvent;
    NSAssert(validMessageType, @"The 'messageType' variable is not valid.");
    
    BOOL validExecStatus = !MPIsNull(execStatus) && [execStatus isKindOfClass:[MPKitExecStatus class]];
    NSAssert(validExecStatus, @"The 'execStatus' variable is not valid.");
    
    BOOL validKitFilter = MPIsNull(kitFilter) || [kitFilter isKindOfClass:[MPKitFilter class]];
    NSAssert(validKitFilter, @"The 'kitFilter' variable is not valid.");
    
    BOOL validOriginalEvent = MPIsNull(originalEvent) || [originalEvent isKindOfClass:[MPEvent class]] || [originalEvent isKindOfClass:[MPCommerceEvent class]];
    NSAssert(validOriginalEvent, @"The 'originalEvent' variable is not valid.");
    
    if (!self || !validMessageType || !validExecStatus || !validKitFilter || !validOriginalEvent) {
        return nil;
    }
    
    _forwardRecordId = 0;
    _dataDictionary = [[NSMutableDictionary alloc] init];
    _dataDictionary[kMPFRModuleId] = execStatus.kitCode;
    _dataDictionary[kMPTimestampKey] = MPCurrentEpochInMilliseconds;
    _dataDictionary[kMPMessageTypeKey] = [NSString stringWithCString:mParticle::MessageTypeName::nameForMessageType(static_cast<mParticle::MessageType>(messageType)).c_str()
                                                            encoding:NSUTF8StringEncoding];

    if (!kitFilter) {
        return self;
    }
    
    if (messageType == MPMessageTypeCommerceEvent || messageType == MPMessageTypeEvent) {
        NSString *eventTypeString = nil;
        if ([originalEvent isKindOfClass:[MPEvent class]]) {
            eventTypeString = ((MPEvent *)originalEvent).typeName;
        } else if ([originalEvent isKindOfClass:[MPCommerceEvent class]]) {
            eventTypeString = [NSString stringWithCString:mParticle::EventTypeName::nameForEventType(static_cast<mParticle::EventType>([((MPCommerceEvent *)originalEvent) type])).c_str()
                                                 encoding:NSUTF8StringEncoding];
        }
        
        if (eventTypeString) {
            _dataDictionary[kMPEventTypeKey] = eventTypeString;
        }
    }
    if ([originalEvent isKindOfClass:[MPEvent class]] && (messageType == MPMessageTypeScreenView || messageType == MPMessageTypeEvent)) {
        _dataDictionary[kMPEventNameKey] = ((MPEvent *)originalEvent).name;
    }
    
    if (kitFilter.appliedProjections.count > 0) {
        NSMutableArray *projections = [[NSMutableArray alloc] initWithCapacity:kitFilter.appliedProjections.count];
        NSMutableDictionary *projectionDictionary;
        
        for (MPEventProjection *eventProjection in kitFilter.appliedProjections) {
            projectionDictionary = [[NSMutableDictionary alloc] initWithCapacity:4];
            projectionDictionary[kMPFRProjectionId] = @(eventProjection.projectionId);
            projectionDictionary[kMPMessageTypeKey] = [NSString stringWithCString:mParticle::MessageTypeName::nameForMessageType(static_cast<mParticle::MessageType>(eventProjection.messageType)).c_str()
                                                                         encoding:NSUTF8StringEncoding];
            
            projectionDictionary[kMPEventTypeKey] = [NSString stringWithCString:mParticle::EventTypeName::nameForEventType(static_cast<mParticle::EventType>(eventProjection.eventType)).c_str()
                                                                       encoding:NSUTF8StringEncoding];
            
            if (eventProjection.projectedName) {
                projectionDictionary[kMPFRProjectionName] = eventProjection.projectedName;
            }
            
            [projections addObject:projectionDictionary];
        }
        
        _dataDictionary[kMPFRProjections] = projections;
    }

    return self;
}

- (NSNumber *)timestamp {
    return _dataDictionary[kMPTimestampKey];
}

- (void)setTimestamp:(NSNumber *)timestamp {
    if (timestamp) {
        _dataDictionary[kMPTimestampKey] = timestamp;
    }
}

- (NSString *)description {
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"MPForwardRecord {\n"];
    [description appendFormat:@"  forwardRecordId: %llu\n", _forwardRecordId];
    [description appendFormat:@"  dataDictionary: %@\n", _dataDictionary];
    [description appendString:@"}"];
    
    return description;
}

- (BOOL)isEqual:(id)object {
    if (MPIsNull(object) || ![object isKindOfClass:[MPForwardRecord class]]) {
        return NO;
    }
    
    MPForwardRecord *objectForwardRecord = (MPForwardRecord *)object;
    
    BOOL isEqual = [_dataDictionary isEqualToDictionary:objectForwardRecord.dataDictionary];
    
    if (isEqual && _forwardRecordId > 0 && objectForwardRecord.forwardRecordId > 0) {
        isEqual = _forwardRecordId == objectForwardRecord.forwardRecordId;
    }
    
    return isEqual;
}

#pragma mark Public methods
- (NSData *)dataRepresentation {
    if (MPIsNull(_dataDictionary) || ![_dataDictionary isKindOfClass:[NSDictionary class]]) {
        MPILogWarning(@"Invalid Data dictionary.");
        return nil;
    }
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:_dataDictionary options:0 error:&error];
    
    if (!error) {
        return data;
    } else {
        MPILogError(@"Error serializing the dictionary into a data representation: %@", [error localizedDescription]);
        return nil;
    }
}

@end
