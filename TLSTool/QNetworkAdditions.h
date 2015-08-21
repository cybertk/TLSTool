/*
     File: QNetworkAdditions.h
 Abstract: Compatibility shim for OS X 10.10 / iOS 8 networking methods.
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

/*! Compatibility shim for OS X 10.10 / iOS 8 networking methods
 * 
 *  \details OS X 10.10 / iOS 8 are expected to add some extremely useful class 
 *  methods to NSStream.  This class contains a methods that are compatible 
 *  with the new methods but which you can call on earlier systems.  These include:
 */

@interface QNetworkAdditions : NSObject

/*! Creates a pair of streams that connect over TCP to a DNS name and port number.
 *
 *  \details This is a simple wrapper around CFStreamCreatePairWithSocketToHost, as 
 *  described in QA1652 "Using NSStreams For A TCP Connection Without NSHost".
 *
 *  <https://developer.apple.com/library/ios/#qa/qa1652/_index.html>
 *
 *  \param hostname The DNS name of the host to connect to; must not be nil.
 *  \param port The port number on that host to connect to; must be in the range 1...65535.
 *  \param inputStream A pointer to an input stream variable; must not be NULL; on entry 
 *  the value is ignored; on return the value will be a valid input stream.
 *  \param outputStream A pointer to an output stream variable; must not be NULL; on entry 
 *  the value is ignored; on return the value will be a valid output stream.
 */

+ (void)getStreamsToHostWithName:(NSString *)hostname 
    port:(NSInteger)port 
    inputStream:(__autoreleasing NSInputStream **)inputStream 
    outputStream:(__autoreleasing NSOutputStream **)outputStream;

/*! Creates a pair of bound streams.
 *
 *  \details This is a simple wrapper around CFStreamCreateBoundPair.
 *
 *  \param bufferSize The size of the buffer between the streams.
 *  \param inputStream A pointer to an input stream variable; must not be NULL; on entry 
 *  the value is ignored; on return the value will be a valid input stream.
 *  \param outputStream A pointer to an output stream variable; must not be NULL; on entry 
 *  the value is ignored; on return the value will be a valid output stream.
 */

+ (void)getBoundStreamsWithBufferSize:(NSUInteger)bufferSize 
    inputStream:(__autoreleasing NSInputStream **)inputStream 
    outputStream:(__autoreleasing NSOutputStream **)outputStream;

@end
