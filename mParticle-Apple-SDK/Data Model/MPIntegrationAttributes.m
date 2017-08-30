//
//  MPIntegrationAttributes.m
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

#import "MPIntegrationAttributes.h"
#import "MPKitInstanceValidator.h"
#import "MPILogger.h"

@implementation MPIntegrationAttributes

- (nonnull instancetype)initWithKitCode:(nonnull NSNumber *)kitCode attributes:(nonnull NSDictionary<NSString *, NSString *> *)attributes {
    BOOL validKitCode = [MPKitInstanceValidator isValidKitCode:kitCode];
    
    __block BOOL validIntegrationAttributes = !MPIsNull(attributes) && attributes.count > 0;
    
    if (validKitCode && validIntegrationAttributes) {
        Class NSStringClass = [NSString class];
        [attributes enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            validIntegrationAttributes = [key isKindOfClass:NSStringClass] && [obj isKindOfClass:NSStringClass];
            
            if (!validIntegrationAttributes) {
                MPILogError(@"Integration attributes must be a dictionary of string, string.");
                *stop = YES;
            }
        }];
    }

    if (!validKitCode || !validIntegrationAttributes) {
        return nil;
    }
    
    self = [super init];
    if (self) {
        _kitCode = kitCode;
        _attributes = attributes;
    }

    return self;
}

- (nonnull instancetype)initWithKitCode:(nonnull NSNumber *)kitCode attributesData:(nonnull NSData *)attributesData {
    NSError *error = nil;
    NSDictionary *attributes = nil;
    
    if (MPIsNull(attributesData)) {
        return nil;
    }
    
    @try {
        attributes = [NSJSONSerialization JSONObjectWithData:attributesData options:0 error:&error];
    } @catch (NSException *exception) {
    }
    
    if (!attributes && error != nil) {
        return nil;
    }
    
    self = [self initWithKitCode:kitCode attributes:attributes];
    return self;
}

#pragma mark MPDataModelProtocol
- (NSDictionary *)dictionaryRepresentation {
    NSDictionary<NSString *, NSDictionary<NSString *, NSString*> *> *dictionary = @{[_kitCode stringValue]:_attributes};
    return dictionary;
}

- (NSString *)serializedString {
    NSDictionary *dictionaryRepresentation = [self dictionaryRepresentation];
    NSError *error = nil;
    NSData *dataRepresentation = nil;
    
    @try {
        dataRepresentation = [NSJSONSerialization dataWithJSONObject:dictionaryRepresentation options:0 error:&error];
    } @catch (NSException *exception) {
    }
    
    if (dataRepresentation.length == 0 && error != nil) {
        return nil;
    }
    
    NSString *stringRepresentation = [[NSString alloc] initWithData:dataRepresentation encoding:NSUTF8StringEncoding];
    return stringRepresentation;
}

@end
