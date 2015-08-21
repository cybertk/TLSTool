# TLSTool

TLSTool is a sample that shows how to implement Transport Layer Security (TLS), and its predecessor, Secure Sockets Layer (SSL), using the NSStream API.  TLSTool demonstrates TLS in both client and server mode.

TLSTool can also be used to explore TLS interactively, much like OpenSSL's s_client and s_server subcommands.  However, because TLSTool uses the OS's built-in TLS stack, it will behave more like other built-in apps that use TLS (Mail, Safari, and so on).

TLSTool requires OS X 10.9 but the core TLS techniques it shows are compatible with OS X back to at least OS X 10.4 (and all versions of iOS for that matter).

## Getting Started

It's easy to use TLSTool to run a simple TLS client test.  For example, to fetch the URL <https://apple.com/>:

```
TLSTool s_client -connect apple.com:443

*  input stream did open
* output stream did open
* output stream has space
* trust result: unspecified
* certificate subjects:
*   0 apple.com
*   1 Entrust Certification Authority - L1C
*   2 Entrust.net Certification Authority (2048)
*   3 Entrust.net Secure Server Certification Authority
```

IMPORTANT: To test the server code you will need a TLS server digital identity in your keychain.  If you don't have one handy, you can create one using the instructions in Technote 2326 "Creating Certificates for TLS Testing".

<https://developer.apple.com/library/mac/technotes/tn2326/_index.html>

In the following example the TLS server digital identity is called "guy-smiley.local." and it's issued by the "QSecure CA" certificate authority.

To test the server code:

```
TLSTool s_server -cert guy-smiley.local
* server identity: guy-smiley.local
* server did start
```

Note: If you don't supply a port number (via the "-accept" command line argument) the server listens on port 4433.

In the client window, run the tool as shown below:

```
TLSTool s_client -noverify

*  input stream did open
* output stream did open
* output stream has space
* trust result: recoverable trust failure
* certificate subjects:
*   0 guy-smiley.local
*   1 QSecure CA
```

Note: If you don't supply a connection address (via the "-connect" command line argument) the client connects to localhost:4433.

Note: The "-noverify" option disables TLS server trust evaluation, allowing the connection to succeed even though the server's certificate is not trusted by the system.  If I configured the system to trust the "QSecure CA" root certificate it would not be necessary.

## How it Works

The project contains lots of networking code that's the same as any other NSStream-based networking app.  You can see the code in TLSToolCommon but you'd probably be better off looking at other, simpler samples, including:

- [SimpleNetworkStreams](https://developer.apple.com/library/ios/#samplecode/SimpleNetworkStreams/)

- [WiTap](https://developer.apple.com/library/ios/#samplecode/WiTap/)


If you're interested in TLS you should focus on the TLSToolClient and TLSToolServer classes, each of which is quite small.  Specifically:

- `[TLSToolClient run]` shows how to set up a stream pair for TLS client operation
- `[TLSToolServer startConnectionWithInputStream:outputStream:]` shows how to set up a stream pair for TLS server operation

## Caveats

The tool's command line arguments are somewhat compatible with OpenSSL's s_client and s_server subcommands.  This compatibility layer is wafer thin; there are lots of options that just aren't implemented, and some options that don't work the same way as OpenSSL.  For example, the OpenSSL s_client subcommand disables TLS server trust evaluation by default but TLSTool leaves it enabled because disabling it is, in general, a bad idea.

The goal of TLSTool is not to provide 100% compatibility with OpenSSL's commands, but rather to a) be a reasonable code sample, and b) provide basic compatibility to preserve 'muscle memory'.  Improving the latter would undermine the former.

## Feedback

If you find any problems with this sample, or you'd like to suggest improvements, please file a bug against it.

<http://developer.apple.com/bugreporter/>
