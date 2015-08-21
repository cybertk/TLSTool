/*
     File: TLSToolCommon.h
 Abstract: Code shared between the client and server.
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

@import Foundation;

/*! A base class shared by the s_client and s_server command code.
 *  \details This is where the bulk of the networking code exists. The subclasses 
 *  just set up the streams correctly and then call down here to do the real work.
 * 
 *  This code's main function is to manage the input and output streams:
 *
 *  - For the input stream, it reads any data that arrives on the stream and 
 *    writes it to stdout.
 *
 *  - For the output stream, it reads any data that arrives on stdin and writes 
 *    it to the stream.
 */

@interface TLSToolCommon : NSObject

// The following are API that clients can reasonable access.

@property (atomic, assign, readwrite) BOOL              showCertificates;   ///< Set to YES to have the code display a hex dump of each certificate received.
@property (atomic, assign, readwrite) BOOL              translateCRToCRLF;  ///< Set to YES to have the stdin reading code convert LF to CR LF.

// The following declarations are for subclassers only.

- (instancetype)init;

/*! Returns a subject summary string for the specified identity.
 *  \param identity The identity whose subject you're looking for; must not be NULL.
 *  \returns A subject summary to log.
 */

- (NSString *)subjectSummaryForIdentity:(SecIdentityRef)identity;

/*! Starts a connection running over the specified stream pair.
 *  \details The streams are scheduled to run asynchronously.  The work 
 *  is done on a serial queue that you can access via the queue property.
 *  Must be called on that queue.
 *  \param inputStream The input stream of the pair; must not be nil.
 *  \param outputStream The input stream of the pair; must not be nil.
 */

- (void)startConnectionWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;

/*! Called when the connection closes.
 *  \details The client subclass overrides this so that it can quit when 
 *  the connection closes.  Called on the object's queue.
 *  \param error An error value indicating why the connection closed, or 
 *  nil if the connection closed due to EOF.
 */

- (void)connectionDidCloseWithError:(NSError *)error;

@property (atomic, assign, readonly ) BOOL              isStarted;          ///< Returns YES if there's are input streams in place; can only be accessed on the object's queue.

@property (atomic, strong, readonly ) dispatch_queue_t  queue;              ///< The dispatch queue used for all processing.

/*! Logs the specified message.
 *  \details This can be called from any context.
 *  \param format A standard NSString format string.
 */

- (void)logWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

@end
