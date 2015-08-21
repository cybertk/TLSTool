/*
     File: TLSToolCommon.m
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

#import "TLSToolCommon.h"

#import "QHex.h"

@interface TLSToolCommon () <NSStreamDelegate>

@property (atomic, strong, readonly ) dispatch_source_t stdinSource;

@property (atomic, strong, readwrite) NSInputStream *   inputStream;
@property (atomic, strong, readwrite) NSOutputStream *  outputStream;
@property (atomic, assign, readwrite) BOOL              hasSpaceAvailable;
@property (atomic, strong, readonly ) NSMutableData *   outputBuffer;
@property (atomic, assign, readwrite) BOOL              haveShownCertificatesForConnection;

@end

@implementation TLSToolCommon

static int sTLSToolKey = 42;

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        NSString *      queueName;
        
        queueName = [NSString stringWithFormat:@"%@.queue", NSStringFromClass([self class])];
        self->_queue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(self->_queue, &sTLSToolKey, (__bridge void *) self, NULL);

        self->_outputBuffer = [[NSMutableData alloc] init];

        // Create an input source that reads stdin and routes it to the output stream.
        
        self->_stdinSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, self.queue);
        dispatch_source_set_event_handler(self->_stdinSource, ^{
            assert([self runningOnOwnQueue]);
            [self readAndSendStdin];
        });
        dispatch_resume(self->_stdinSource);
    }
    return self;
}

- (void)dealloc
    // This object is not set up to be deallocated.
{
    assert(NO);
}

/*! Determines if the current thread is running on the queue associated with self.
 *  \returns YES if is it; NO otherwise.
 */

- (BOOL)runningOnOwnQueue
{
    return dispatch_get_specific(&sTLSToolKey) == (__bridge void *) self;
}

- (NSString *)subjectSummaryForIdentity:(SecIdentityRef)identity
{
    BOOL                    success;
    NSString *              result;
    SecCertificateRef       certificate;
    
    NSParameterAssert(identity != NULL);
    
    success = SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess;
    assert(success);
    
    result = CFBridgingRelease( SecCertificateCopySubjectSummary(certificate) );
    CFRelease(certificate);

    return result;
}

- (void)startConnectionWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
    assert([self runningOnOwnQueue]);
    
    self.inputStream  = inputStream;
    self.outputStream = outputStream;
    
    [self.inputStream  setDelegate:self];
    [self.outputStream setDelegate:self];

    CFReadStreamSetDispatchQueue( (__bridge CFReadStreamRef ) self.inputStream,  self.queue);
    CFWriteStreamSetDispatchQueue((__bridge CFWriteStreamRef) self.outputStream, self.queue);

    [self.inputStream  open];
    [self.outputStream open];
}

- (BOOL)isStarted
{
    assert([self runningOnOwnQueue]);
    return self.inputStream != nil;
}

- (void)connectionDidCloseWithError:(NSError *)error
{
    #pragma unused(error)
    // do nothing
}

/*! Stops the current connection, cleaning up all its state.
 *  \param error If not nil, this is the error that caused the connection to 
 *  stop; nil if the connection stopped due to EOF.
 */

- (void)stopConnectionWithError:(NSError *)error
{
    if (error == nil) {
        [self logWithFormat:@"close"];
    } else {
        [self logWithFormat:@"error %@ / %d", [error domain], (int) [error code]];
    }
    [self.inputStream  setDelegate:nil];
    [self.outputStream setDelegate:nil];
    if (self.inputStream != NULL) {
        CFReadStreamSetDispatchQueue(  (CFReadStreamRef ) self.inputStream,  NULL);
    }
    if (self.outputStream != NULL) {
        CFWriteStreamSetDispatchQueue( (CFWriteStreamRef) self.outputStream, NULL);
    }
    [self.inputStream  close];
    [self.outputStream close];
    self.inputStream  = nil;
    self.outputStream = nil;
    
    self.hasSpaceAvailable = NO;
    [self.outputBuffer setLength:0];
    self.haveShownCertificatesForConnection = NO;
    
    [self connectionDidCloseWithError:error];
}

- (void)logWithFormat:(NSString *)format, ...
{
    va_list             ap;
    NSString *          str;
    NSMutableArray *    lines;

    // assert([self runningOnOwnQueue]);        -- We specifically allow this off the standard queue.
    
    va_start(ap, format);
    str = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    
    lines = [[NSMutableArray alloc] init];
    [str enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        #pragma unused(stop)
        [lines addObject:[[NSString alloc] initWithFormat:@"* %@\n", line]];
    }];
    (void) fprintf(stdout, "%s", [[lines componentsJoinedByString:@""] UTF8String]);
    (void) fflush(stdout);
}

/*! Logs information about the trust evaluation.
 *  \details This routine is called on each has-{space,data}-available event.  If the 
 *  showCertificates property is set then, the first time it's called, it logs information 
 *  from the trust object associated with the stream.
 *  
 *  Note that we do this on the has-{space,data}-available event, not the open event, 
 *  because the trust object isn't set up at the point that the open event is delivered.
 */

- (void)logTrustDetails
{
    if ( ! self.haveShownCertificatesForConnection ) {
        OSStatus            err;
        SecTrustRef         trust;
        SecTrustResultType  trustResult;
        NSString *          trustResultStr;
        CFIndex             certificateCount;
        CFIndex             certificateIndex;
        
        trust = (SecTrustRef) CFReadStreamCopyProperty( (__bridge CFReadStreamRef) self.inputStream, kCFStreamPropertySSLPeerTrust);
        if (trust == nil) {
            [self logWithFormat:@"no trust"];
        } else {
            err = SecTrustEvaluate(trust, &trustResult);
            if (err != errSecSuccess) {
                [self logWithFormat:@"trust evaluation failed: %d", (int) err];
            } else {
                switch (trustResult) {
                    case kSecTrustResultInvalid:                 { trustResultStr = @"invalid";                   } break;
                    case kSecTrustResultProceed:                 { trustResultStr = @"proceed";                   } break;
                    case kSecTrustResultDeny:                    { trustResultStr = @"deny";                      } break;
                    case kSecTrustResultUnspecified:             { trustResultStr = @"unspecified";               } break;
                    case kSecTrustResultRecoverableTrustFailure: { trustResultStr = @"recoverable trust failure"; } break;
                    case kSecTrustResultFatalTrustFailure:       { trustResultStr = @"Fatal trust failure";       } break;
                    case kSecTrustResultOtherError:              { trustResultStr = @"other error";               } break;
                    default: {
                        trustResultStr = [NSString stringWithFormat:@"%u", (unsigned int) trustResult];
                    } break;
                }
                [self logWithFormat:@"trust result: %@", trustResultStr];
                certificateCount = SecTrustGetCertificateCount(trust);
                [self logWithFormat:@"certificate subjects:"];
                for (certificateIndex = 0; certificateIndex < certificateCount; certificateIndex++) {
                    [self logWithFormat:@"  %zu %@", 
                        (size_t) certificateIndex, 
                        CFBridgingRelease( SecCertificateCopySubjectSummary( SecTrustGetCertificateAtIndex(trust, certificateIndex) ) )
                    ];
                }
                if (self.showCertificates) {
                    [self logWithFormat:@"certificate data:"];
                    for (certificateIndex = 0; certificateIndex < certificateCount; certificateIndex++) {
                        [self logWithFormat:@"  %zu %@", 
                            (size_t) certificateIndex, 
                            [QHex hexStringWithData:CFBridgingRelease( SecCertificateCopyData( SecTrustGetCertificateAtIndex(trust, certificateIndex) ) )]
                        ];
                    }
                }
            }
            CFRelease(trust);
        }

        self.haveShownCertificatesForConnection = YES;
    }
}

/*! Reads data from stdin and sends it to the output stream.
 *  \details This is called by a dispatch event source handler when 
 *  stdin has data available.  It makes a single read call to get 
 *  what data is currently there and sends it to the output stream.
 */

- (void)readAndSendStdin
{
    ssize_t         bytesRead;
    uint8_t         buf[2048];
    
    assert([self runningOnOwnQueue]);
    
    bytesRead = read(STDIN_FILENO, buf, sizeof(buf));
    if (bytesRead < 0) {
        [self stopConnectionWithError:[NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]];
    } else if (bytesRead == 0) {
        [self stopConnectionWithError:nil];
    } else if (self.outputStream == nil) {
        [self logWithFormat:@"could not send data; no connection"];
    } else {
        NSMutableData *     newData;
        
        newData = [NSMutableData dataWithBytes:buf length:(NSUInteger) bytesRead];
        
        if (self.translateCRToCRLF) {
            NSUInteger      index;
            
            // Convert CR to CRLF in newData.
            
            index = 0;
            while (index != [newData length]) {
                if (*(uint8_t *) [newData mutableBytes] == '\n') {
                    [newData replaceBytesInRange:NSMakeRange(index, 1) withBytes:"\r\n" length:2];
                    index += 2;
                } else {
                    index += 1;
                }
            }
        }
        
        if (([newData length] + [self.outputBuffer length]) > 4096) {
            [self stopConnectionWithError:[NSError errorWithDomain:NSPOSIXErrorDomain code:ENOBUFS userInfo:nil]];
        } else {
            [self.outputBuffer appendData:newData];
            if (self.hasSpaceAvailable) {
                [self sendData];
            }
        }
    }
}

/*! Attemps to send data from the output buffer.
 *  \details Called in two situations:
 *
 *  - when new data is placed in the output buffer and we've previously 
 *    ignored a has-space-available event because of the lack of data
 *
 *  - when space has become available
 *
 *  It checks to see if there is data in the output buffer.  If there is, 
 *  it sends what it can to the output stream and then removes the sent 
 *  data from the buffer.
 */

- (void)sendData
{
    NSInteger       bytesWritten;
    
    assert(self.hasSpaceAvailable);
    if ([self.outputBuffer length] != 0) {
        self.hasSpaceAvailable = NO;
        
        bytesWritten = [self.outputStream write:[self.outputBuffer bytes] maxLength:[self.outputBuffer length]];
        if (bytesWritten > 0) {
            [self.outputBuffer replaceBytesInRange:NSMakeRange(0, (NSUInteger) bytesWritten) withBytes:NULL length:0];
        }
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    NSString *  streamName;

    assert([self runningOnOwnQueue]);
    
    streamName = aStream == self.inputStream ? @" input" : @"output";
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            [self logWithFormat:@"%@ stream did open", streamName];
        } break;
        case NSStreamEventHasBytesAvailable: {
            NSInteger   bytesRead;
            uint8_t     buffer[2048];
            
            [self logWithFormat:@"%@ stream has bytes", streamName];
            [self logTrustDetails];
            bytesRead = [self.inputStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead > 0) {
                (void) fwrite(buffer, 1, (size_t) bytesRead, stdout);
                (void) fflush(stdout);
            }
        } break;
        case NSStreamEventHasSpaceAvailable: {
            [self logWithFormat:@"%@ stream has space", streamName];
            [self logTrustDetails];
            self.hasSpaceAvailable = YES;
            [self sendData];
        } break;
        default:
            assert(NO);
            // fall through
        case NSStreamEventEndEncountered: {
            [self logWithFormat:@"%@ stream end", streamName];
            [self stopConnectionWithError:nil];
        } break;
        case NSStreamEventErrorOccurred: {
            NSError *   error;
            
            error = [aStream streamError];
            [self stopConnectionWithError:error];
        } break;
    }
}

@end
