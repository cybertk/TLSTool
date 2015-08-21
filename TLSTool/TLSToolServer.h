/*
     File: TLSToolServer.h
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

#import "TLSToolCommon.h"

/*! Determines how the server authentications clients.
 */

typedef NS_ENUM(NSUInteger, TLSToolServerAuthenticatesClient) {
    TLSToolServerAuthenticatesClientNone,                       ///< The server does not even ask for the client for a certificate.
    TLSToolServerAuthenticatesClientRequestCertificate,         ///< The server asks the client for a certificate but does no trust evaluation if it gets one.
    TLSToolServerAuthenticatesClientRequestTrustedCertificate,  ///< The server asks the client for a certificate and does standard trust evaluation if it gets one.
    TLSToolServerAuthenticatesClientRequireCertificate,         ///< The server requires the client to supply a certificate but does no trust evaluation on it.
    TLSToolServerAuthenticatesClientRequireTrustedCertificate   ///< The server requires the client to supply a certificate and does standard trust evaluation on it.
};

/*! An object that implements the tool's s_server command.
 *  \details To use this class, simply initialise it with a TLS server identity and 
 *  port and then call -run.  Before calling -run you can optionally configure 
 *  various parameters that modify its behaviour.
 */

@interface TLSToolServer : TLSToolCommon

/*! Initialises the object to server TLS connections with the specified identity from the specified port.
 *  \param serverIdentity The server identity to use; must not be NULL.
 *  \param port The port to listen on; must be in the range 1..65535, inclusive.
 *  \returns An initialised object.
 */

- (instancetype)initWithServerIdentify:(SecIdentityRef)serverIdentity port:(NSInteger)port;

@property (atomic, assign, readonly ) SecIdentityRef    serverIdentity;     ///< The server identity to use; set by the init method.
@property (atomic, assign, readonly ) NSInteger         port;               ///< The port to listen on; set by the init method.

/*! Runs the command, never returning.
 */

- (void)run __attribute__ ((noreturn));

// showCertificates and translateCRToCRLF properties inherited from TLSToolCommon

@property (atomic, assign, readwrite) TLSToolServerAuthenticatesClient  serverAuthenticatesClient;  ///< Controls how the server authenticates clients; see the discussion of TLSToolServerAuthenticatesClient.

@end
