/*
     File: TLSToolClient.m
 Abstract: Core of the s_client implementation.
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 */

#import "TLSToolClient.h"

#import "QNetworkAdditions.h"
#import "QHex.h"

@interface TLSToolClient ()

@end

@implementation TLSToolClient {
    SecIdentityRef  _clientIdentity;
}

- (instancetype)initWithHostName:(NSString *)hostName port:(NSInteger)port
{
    NSParameterAssert(hostName != nil);
    NSParameterAssert( (port > 0) && (port < 65536) );
    self = [super init];
    if (self != nil) {
        self->_hostName = [hostName copy];
        self->_port = port;
    }
    return self;
}

- (SecIdentityRef)clientIdentity
{
    @synchronized (self) {
        if (self->_clientIdentity == NULL) {
            return NULL;
        } else {
            return (SecIdentityRef) CFAutorelease( CFRetain(self->_clientIdentity) );
        }
    }
}

- (void)setClientIdentity:(SecIdentityRef)newValue
{
    @synchronized (self) {
        if (newValue != self->_clientIdentity) {
            if (self->_clientIdentity != NULL) {
                CFRelease(self->_clientIdentity);
            }
            self->_clientIdentity = newValue;
            if (self->_clientIdentity != NULL) {
                CFRetain(self->_clientIdentity);
            }
        }
    }
}

- (void)run
{
    dispatch_async(self.queue, ^{
        BOOL                success;
        NSInputStream *     inStream;
        NSOutputStream *    outStream;
        
        if (self.clientIdentity != NULL) {
            [self logWithFormat:@"client identity: %@", [self subjectSummaryForIdentity:self.clientIdentity]];
        }
        
        // Create and configure our streams.
        
        [QNetworkAdditions getStreamsToHostWithName:self.hostName port:self.port inputStream:&inStream outputStream:&outStream];

        if (NO) {
            // In many cases you can enable TLS with this code, which assumes a whole bunch 
            // of standard defaults.  In our case, however, we need to configure some non-standard 
            // properties so we have to use kCFStreamPropertySSLSettings.

            success = [inStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
            assert(success);
        } else {
            NSMutableDictionary *   settings;
            
            settings = [NSMutableDictionary dictionary];
            if (self.disableServerTrustEvaluation) {
                settings[ (__bridge id)  kCFStreamSSLValidatesCertificateChain ] = @NO;
            }
            if (self.clientIdentity != NULL) {
                settings[ (__bridge id) kCFStreamSSLCertificates ] = @[ (__bridge id) self.clientIdentity ];
            }
            success = CFReadStreamSetProperty(
                (__bridge CFReadStreamRef) inStream, 
                kCFStreamPropertySSLSettings, 
                (__bridge CFDictionaryRef) settings
            ) != false;
            assert(success);
        }

        [self startConnectionWithInputStream:inStream outputStream:outStream];
    });
    
    dispatch_main();
}

- (void)connectionDidCloseWithError:(NSError *)error
{
    exit(error == nil ? EXIT_SUCCESS : EXIT_FAILURE);
}

@end
