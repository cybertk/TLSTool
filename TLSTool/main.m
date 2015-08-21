/*
     File: main.m
 Abstract: Command line tool main.
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

#import "TLSToolClient.h"
#import "TLSToolServer.h"

/*! Parses a port string and returns its numeric value.
 *  \param portStr The string to parse.
 *  \param portPtr A pointer to a place to store the port number; must not be NULL; 
 *  on call, the value is ignored; on success, this will be a port number; on failure, 
 *  the value is unmodified.
 *  \returns EXIT_SUCCESS on success; EXIT_FAILURE otherwise.
 */

static int ParsePort(NSString * portStr, NSInteger * portPtr)
{
    int             result;
    NSScanner *     s;
    NSInteger       port;
    
    assert(portStr != NULL);
    assert(portPtr != NULL);
    
    result = EXIT_FAILURE;
    s = [NSScanner scannerWithString:portStr];
    if ([s scanInteger:&port]) {
        if ([s isAtEnd]) {
            if ( (port > 0) && (port < 65536) ) {
                *portPtr = port;
                result = EXIT_SUCCESS;
            }
        }
    }
    return result;
}

/*! Parses a client:port string and returns the two components.
 *  \param arg The string to parse; may be NULL, which guarantees failure.
 *  \param clientHostPtr A pointer to a place to store the host string; must not be NULL;
 *  on call, the value is ignored; on success, this will be an autoreleased string; on 
 *  failure, the value is unmodified.
 *  \param portPtr A pointer to a place to store the port number; must not be NULL; 
 *  on call, the value is ignored; on success, this will be a port number; on failure, 
 *  the value is unmodified.
 *  \returns EXIT_SUCCESS on success; EXIT_FAILURE otherwise.
 */

static int ParseClientHostAndPort(const char * arg, __autoreleasing NSString ** clientHostPtr, NSInteger * portPtr)
{
    int             result;
    NSString *      argStr;
    NSRange         lastColonRange;
    NSString *      hostStr;
    NSString *      portStr;
    
    // arg may be null
    assert(clientHostPtr != NULL);
    assert(portPtr != NULL);

    result = EXIT_FAILURE;
    
    if (arg != NULL) {
        argStr = [NSString stringWithUTF8String:arg];
        if (argStr != nil) {
            lastColonRange = [argStr rangeOfString:@":" options:NSBackwardsSearch];
            if (lastColonRange.location != NSNotFound) {
                hostStr = [argStr substringToIndex:lastColonRange.location];
                portStr = [argStr substringFromIndex:lastColonRange.location + lastColonRange.length];
                result = ParsePort(portStr, portPtr);
                if (result == EXIT_SUCCESS) {
                    *clientHostPtr = hostStr;
                }
            }
        }
    }
    
    return result;
}

/*! Parses a port string and returns its numeric value.
 *  \param arg The string to parse; may be NULL, which guarantees failure.
 *  \param portPtr A pointer to a place to store the port number; must not be NULL; 
 *  on call, the value is ignored; on success, this will be a port number; on failure, 
 *  the value is unmodified.
 *  \returns EXIT_SUCCESS on success; EXIT_FAILURE otherwise.
 */
 
static int ParseServerPort(const char * arg, NSInteger * portPtr)
{
    int             result;
    NSString *      argStr;
    
    // arg may be null
    assert(portPtr != NULL);

    result = EXIT_FAILURE;
    
    if (arg != NULL) {
        argStr = [NSString stringWithUTF8String:arg];
        if (argStr != nil) {
            result = ParsePort(argStr, portPtr);
        }
    }
    
    return result;
}

/*! Searches the keychain and returns an identity for the specified name.
 *  \details It first looks for an exact match, then looks for a fuzzy 
 *  match (a case and diacritical insensitive substring).
 *  \param arg The name to look for; may be NULL, which guarantees failure.
 *  \param identityPtr A pointer to a place to store the identity; must not be NULL; 
 *  on call, the value is ignored; on success, this will be an identity that the 
 *  caller must release; on failure, the value is unmodified.
 *  \returns EXIT_SUCCESS on success; EXIT_FAILURE otherwise.
 */

static int CopyIdentityNamed(const char * arg, SecIdentityRef * identityPtr)
{
    NSString *      argStr;
    OSStatus        err;
    CFArrayRef      matchResults;
    SecIdentityRef  identity;

    identity = nil;
    
    if (arg != NULL) {
        argStr = [NSString stringWithUTF8String:arg];
        if (argStr != nil) {
            err = SecItemCopyMatching((__bridge CFDictionaryRef) @{
                    (__bridge id) kSecClass:            (__bridge id) kSecClassIdentity,
                    (__bridge id) kSecReturnRef:        @YES, 
                    (__bridge id) kSecReturnAttributes: @YES,
                    (__bridge id) kSecMatchLimit:       (__bridge id) kSecMatchLimitAll
                }, 
                (CFTypeRef *) &matchResults
            );
            if (err == errSecSuccess) {
                NSArray *       matchResultsArray;
                NSUInteger      matchIndex;

                matchResultsArray = (__bridge NSArray *) matchResults;
                
                // First look for an exact match.
                
                matchIndex = [matchResultsArray indexOfObjectPassingTest:^BOOL(NSDictionary * matchDict, NSUInteger idx, BOOL *stop) {
                    #pragma unused(idx)
                    #pragma unused(stop)
                    return [matchDict[ (__bridge id) kSecAttrLabel ] isEqual:argStr];
                }];
                
                // If that fails, try a fuzzy match.
                
                if (matchIndex == NSNotFound) {
                    matchIndex = [matchResultsArray indexOfObjectPassingTest:^BOOL(NSDictionary * matchDict, NSUInteger idx, BOOL *stop) {
                        #pragma unused(idx)
                        #pragma unused(stop)
                        return [matchDict[ (__bridge id) kSecAttrLabel ] rangeOfString:argStr options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound;
                    }];
                }
                
                if (matchIndex != NSNotFound) {
                    identity = (__bridge SecIdentityRef) matchResultsArray[matchIndex][ (__bridge id) kSecValueRef];
                    assert(CFGetTypeID(identity) == SecIdentityGetTypeID());
                    CFRetain(identity);
                }

                CFRelease(matchResults);
            }
        }
    }
    
    if (identity != NULL) {
        *identityPtr = identity;
    }
    return identity != NULL ? EXIT_SUCCESS : EXIT_FAILURE;
}

int main(int argc, char **argv)
{
    #pragma unused(argc)
    #pragma unused(argv)
    int                 retVal;

    @autoreleasepool {
        BOOL            client;
        NSString *      clientHost;
        NSInteger       port;
        BOOL            showCertificates;
        BOOL            translateCRToCRLF;
        BOOL            disableServerTrustEvaluation;
        TLSToolServerAuthenticatesClient    serverAuthenticatesClient;
        SecIdentityRef  identity;
        size_t          argIndex;
        
        // Parse the command line options.  We can't use <x-man-page://3/getopt> because 
        // we're trying to be openssl-like.

        clientHost = @"localhost";
        port = 4433;
        showCertificates = NO;
        translateCRToCRLF = NO;
        disableServerTrustEvaluation = NO;
        serverAuthenticatesClient = TLSToolServerAuthenticatesClientNone;
        identity = NULL;
        retVal = EXIT_SUCCESS;
        if (argc < 2) {
            retVal = EXIT_FAILURE;
        } else {
            if (strcmp(argv[1], "s_client") == 0) {
                client = YES;

                argIndex = 2;
                while ( (retVal == EXIT_SUCCESS) && (argv[argIndex] != NULL) ) {
                    if (strcmp(argv[argIndex], "-connect") == 0) {
                        argIndex += 1;
                        retVal = ParseClientHostAndPort(argv[argIndex], &clientHost, &port);
                    } else if (strcmp(argv[argIndex], "-cert") == 0) {
                        argIndex += 1;
                        retVal = CopyIdentityNamed(argv[argIndex], &identity);
                    } else if (strcmp(argv[argIndex], "-showcerts") == 0) {
                        showCertificates = YES;
                    } else if (strcmp(argv[argIndex], "-crlf") == 0) {
                        translateCRToCRLF = YES;
                    } else if (strcmp(argv[argIndex], "-noverify") == 0) {
                        disableServerTrustEvaluation = YES;
                    } else {
                        retVal = EXIT_FAILURE;
                    }
                    argIndex += 1;
                }
            } else if (strcmp(argv[1], "s_server") == 0) {
                client = NO;

                argIndex = 2;
                while ( (retVal == EXIT_SUCCESS) && (argv[argIndex] != NULL) ) {
                    if (strcmp(argv[argIndex], "-accept") == 0) {
                        argIndex += 1;
                        retVal = ParseServerPort(argv[argIndex], &port);
                    } else if (strcmp(argv[argIndex], "-cert") == 0) {
                        argIndex += 1;
                        retVal = CopyIdentityNamed(argv[argIndex], &identity);
                    } else if (strcmp(argv[argIndex], "-showcerts") == 0) {
                        showCertificates = YES;
                    } else if (strcmp(argv[argIndex], "-authenticate") == 0) {
                        argIndex += 1;
                        if (argv[argIndex] == NULL) {
                            retVal = EXIT_FAILURE;
                        } else if (strcmp(argv[argIndex], "none") == 0) {
                            serverAuthenticatesClient = TLSToolServerAuthenticatesClientNone;
                        } else if (strcmp(argv[argIndex], "request") == 0) {
                            serverAuthenticatesClient = TLSToolServerAuthenticatesClientRequestCertificate;
                        } else if (strcmp(argv[argIndex], "request-trusted") == 0) {
                            serverAuthenticatesClient = TLSToolServerAuthenticatesClientRequestTrustedCertificate;
                        } else if (strcmp(argv[argIndex], "require") == 0) {
                            serverAuthenticatesClient = TLSToolServerAuthenticatesClientRequireCertificate;
                        } else if (strcmp(argv[argIndex], "require-trusted") == 0) {
                            serverAuthenticatesClient = TLSToolServerAuthenticatesClientRequireTrustedCertificate;
                        } else {
                            retVal = EXIT_FAILURE;
                        }
                    } else {
                        retVal = EXIT_FAILURE;
                    }
                    argIndex += 1;
                }
                
                if (identity == NULL) {
                    retVal = EXIT_FAILURE;
                }
            } else {
                retVal = EXIT_FAILURE;
            }
        }
        
        // On error, print the usage.
        
        if (retVal == EXIT_FAILURE) {
            fprintf(stderr, "usage: %s s_client options\n", getprogname());
            fprintf(stderr, "     s_client options:\n");
            fprintf(stderr, "         -connect host:port\n");
            fprintf(stderr, "         -showcerts\n");
            fprintf(stderr, "         -crlf\n");
            fprintf(stderr, "         -noverify\n");
            fprintf(stderr, "         -cert identityName (found in keychain)\n");
            fprintf(stderr, "       %s s_server options\n", getprogname());
            fprintf(stderr, "     s_server options:\n");
            fprintf(stderr, "         -cert identityName (found in keychain, required)\n");
            fprintf(stderr, "         -accept port (default is 4433)\n");
            fprintf(stderr, "         -authenticate none|request|request-trusted|require|require-trusted\n");
        } else {
        
            // On success, set up and run a client or server object.
            
            if (client) {
                TLSToolClient *     toolClient;
                
                toolClient = [[TLSToolClient alloc] initWithHostName:clientHost port:port];
                toolClient.showCertificates = showCertificates;
                toolClient.translateCRToCRLF = translateCRToCRLF;
                toolClient.disableServerTrustEvaluation = disableServerTrustEvaluation;
                toolClient.clientIdentity = identity;
                [toolClient run];
            } else {
                TLSToolServer *     toolServer;
                
                // SSLSetClientSideAuthenticate
                
                toolServer = [[TLSToolServer alloc] initWithServerIdentify:identity port:port];
                toolServer.showCertificates = showCertificates;
                toolServer.translateCRToCRLF = translateCRToCRLF;
                toolServer.serverAuthenticatesClient = serverAuthenticatesClient;
                [toolServer run];
            }
            // no coming back to here
            assert(NO);
        }
    }

    return retVal;
}
