/*
     File: TLSToolServer.m
 Abstract: Core of the s_server implementation.
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

#import "TLSToolServer.h"

#import "QHex.h"

@interface TLSToolServer () <NSNetServiceDelegate>

@property (atomic, strong, readwrite) NSNetService *    server;     ///< The net service that manages our listening socket.

@property (atomic, assign, readwrite) BOOL              hasPrintedServerDidStartMessage;    ///< See the discussion in -netServiceDidPublish:.

/*! Determines the validates-certificate-chain value from the public serverAuthenticatesClient property.
 *  \details We expose a single serverAuthenticatesClient property that encompasses all reasonable 
 *  values in a single independent variable.  We need to map that value to two somewhat-dependent 
 *  variables, validates-certificate-chain and client-certificate-mode.  This computed property does 
 *  that mapping for the former.
 */

@property (atomic, assign, readonly ) BOOL              validatesCertificateChain;

/*! Determines the client-certificate-mode value from the public serverAuthenticatesClient property.
 *  \details We expose a single serverAuthenticatesClient property that encompasses all reasonable 
 *  values in a single independent variable.  We need to map that value to two somewhat-dependent 
 *  variables, validates-certificate-chain and client-certificate-mode.  This computed property does 
 *  that mapping for the latter.
 */

@property (atomic, assign, readonly ) SSLAuthenticate   clientCertificateMode;

@end

@implementation TLSToolServer {
    SecIdentityRef  _serverIdentity;
}

- (instancetype)initWithServerIdentify:(SecIdentityRef)serverIdentity port:(NSInteger)port
{
    NSParameterAssert(serverIdentity != NULL);
    NSParameterAssert( (port > 0) && (port <= 65536) );
    self = [super init];
    if (self != nil) {
        self->_serverIdentity = serverIdentity;
        CFRetain(self->_serverIdentity);
        self->_port = port;
    }
    return self;
}

- (void)dealloc
    // This object is not set up to be deallocated.
{
    assert(NO);
}

- (SecIdentityRef)serverIdentity
{
    @synchronized (self) {
        return (SecIdentityRef) CFAutorelease( CFRetain(self->_serverIdentity) );
    }
}

- (void)run
{
    [self logWithFormat:@"server identity: %@", [self subjectSummaryForIdentity:self.serverIdentity]];

    // Create the NSNetService object that handles incoming connections.  We don't care 
    // about the domain or name (they both have reasonable defaults) but we have to supply 
    // a type.
    
    self.server = [[NSNetService alloc] initWithDomain:@"" type:@"_x-TLSTool._tcp." name:@"" port:(int) self.port];
    self.server.delegate = self;
    [self.server publishWithOptions:NSNetServiceListenForConnections];

    // Run the server.  We can't use dispatch_main because NSNetService really wants a 
    // run loop <rdar://problem/17960834>.  We have to have an exit() after the 
    // -[NSRunLoop run] because it can return under oddball circumstances.
    
    [[NSRunLoop currentRunLoop] run];
    exit(EXIT_FAILURE);
}

- (BOOL)validatesCertificateChain
{
    BOOL result;

    switch (self.serverAuthenticatesClient) {
        case TLSToolServerAuthenticatesClientNone:
        case TLSToolServerAuthenticatesClientRequestCertificate:
        case TLSToolServerAuthenticatesClientRequireCertificate: {
            result = NO;
        } break;
        case TLSToolServerAuthenticatesClientRequestTrustedCertificate:
        case TLSToolServerAuthenticatesClientRequireTrustedCertificate: {
            result = YES;
        } break;
    }
    return result;
}

- (SSLAuthenticate)clientCertificateMode
{
    SSLAuthenticate         result;

    switch (self.serverAuthenticatesClient) {
        case TLSToolServerAuthenticatesClientNone: {
            result = kNeverAuthenticate;
        } break;
        case TLSToolServerAuthenticatesClientRequestCertificate:
        case TLSToolServerAuthenticatesClientRequestTrustedCertificate: {
            result = kTryAuthenticate;
        } break;
        case TLSToolServerAuthenticatesClientRequireTrustedCertificate: 
        case TLSToolServerAuthenticatesClientRequireCertificate: {
            result = kAlwaysAuthenticate;
        } break;
    }
    return result;
}

- (void)startConnectionWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
    BOOL                    success;
    SSLContextRef           context;
    
    assert(inputStream  != nil);
    assert(outputStream != nil);
    
    // Apply TLS settings based.
    
    success = CFReadStreamSetProperty(
        (__bridge CFReadStreamRef) inputStream, 
        kCFStreamPropertySSLSettings, 
        (__bridge CFDictionaryRef) @{
            (__bridge id) kCFStreamSSLIsServer:                  @YES, 
            (__bridge id) kCFStreamSSLCertificates:              @[ (__bridge id) self.serverIdentity ], 
            (__bridge id) kCFStreamSSLValidatesCertificateChain: @(self.validatesCertificateChain)
        }
    ) != false;
    assert(success);
    
    // Requesting a client certificate can't be done directly using socket streams properties; 
    // instead we get the Secure Transport and set it up there.
    
    context = (SSLContextRef) CFReadStreamCopyProperty((__bridge CFReadStreamRef) inputStream, kCFStreamPropertySSLContext);
    assert(context != NULL);
    success = SSLSetClientSideAuthenticate(context, self.clientCertificateMode) == errSecSuccess;
    assert(success);
    CFRelease(context);

    [super startConnectionWithInputStream:inputStream outputStream:outputStream];
}

- (void)netServiceDidPublish:(NSNetService *)sender
{
    assert(sender == self.server);

    // If you have multiple Bonjour registration domains (you most commonly see this 
    // when Back to My Mac is enabled), -netServiceDidPublish: is called multiple 
    // times, once for each domain.  We don't want to confused our users by printing 
    // multiple "server did start" messages, so we only print that message on the 
    // first call.
    //
    // Note that hasPrintedServerDidStartMessage is never cleared because the server 
    // runs until someone terminates the entire process.

    if ( ! self.hasPrintedServerDidStartMessage ) {
        [self logWithFormat:@"server did start"];
        self.hasPrintedServerDidStartMessage = YES;
    }
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
    assert(sender == self.server);

    [self logWithFormat:@"server startup failed %@ / %@", errorDict[NSNetServicesErrorDomain], errorDict[NSNetServicesErrorCode]];
    exit(EXIT_FAILURE);
}

- (void)netService:(NSNetService *)sender didAcceptConnectionWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
    dispatch_async(self.queue, ^{
        assert(sender == self.server);
    
        if (self.isStarted) {
            // We already have a connecion in place; reject this connection.
            [inputStream  open];
            [outputStream open];
            [inputStream  close];
            [outputStream close];
        } else {
            // Start a connection based on these streams.
            [self startConnectionWithInputStream:inputStream outputStream:outputStream];
        }
    });
}

@end
