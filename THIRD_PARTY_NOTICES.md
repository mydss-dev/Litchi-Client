# Third-party notices

Litchi embeds and distributes [mihomo](https://github.com/MetaCubeX/mihomo),
licensed under GNU GPL v3.

The Android integration follows the public architecture used by
[FlClash](https://github.com/chen08209/FlClash): a `VpnService` creates the TUN
file descriptor, a JNI bridge passes it to the Go core, and outbound sockets
are protected from VPN recursion. No FlClash source file is copied verbatim.
