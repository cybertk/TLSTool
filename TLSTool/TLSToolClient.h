/*
     File: TLSToolClient.h
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

#import "TLSToolCommon.h"

/*! An object that implements the tool's s_client command.
 *  \details To use this class, simply initialise it with a host and port to 
 *  to connect to and then call -run.  Before calling -run you can optionally 
 *  configure various parameters that modify its behaviour.
 */

@interface TLSToolClient : TLSToolCommon

/*! Initialises the object to connect to the specified host and port.
 *  \param hostName The host name (or IPv{4,6} address to connect to; must not be NULL.
 *  \param port The port to connect to; must be in the range 1..65535, inclusive.
 *  \returns An initialised object.
 */

- (instancetype)initWithHostName:(NSString *)hostName port:(NSInteger)port;

@property (atomic, copy,   readonly ) NSString *        hostName;   ///< The host to connect to; set by the init method.
@property (atomic, assign, readonly ) NSInteger         port;       ///< The port to connect to; set by the init method.

/*! Runs the command, never returning.
 */

- (void)run __attribute__ ((noreturn));

// showCertificates and translateCRToCRLF properties inherited from TLSToolCommon

@property (atomic, assign, readwrite) BOOL              disableServerTrustEvaluation;   ///< Set to YES to disable the client's server trust evaluation.
@property (atomic, assign, readwrite) SecIdentityRef    clientIdentity;                 ///< Set to supply an identity to the server (which may or may not check it).

@end
