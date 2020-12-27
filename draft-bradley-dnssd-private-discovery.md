---
To convert this file to text and HTML:
mmark -xml2 -page draft-bradley-dnssd-private-discovery.md > draft-bradley-dnssd-private-discovery-04.xml
xml2rfc --text draft-bradley-dnssd-private-discovery-04.xml -o draft-bradley-dnssd-private-discovery-04.txt
xml2rfc --html draft-bradley-dnssd-private-discovery-04.xml -o draft-bradley-dnssd-private-discovery-04.html
---
%%%
title			= "Private Discovery"
category		= "std"
area			= "Internet"
workgroup		= "Internet Engineering Task Force"
docName			= "draft-bradley-dnssd-private-discovery-04"
ipr				= "trust200902"
date			= 2020-12-27T00:00:00Z

[seriesInfo]
name			= "Internet-Draft"
value			= "draft-bradley-dnssd-private-discovery"
stream			= "IETF"
status			= "standard"

[[author]]
initials		= "B."
surname			= "Bradley"
fullname		= "Bob Bradley"
organization	= "Apple Inc."

[author.address]
email			= "bradley@apple.com"

[author.address.postal]
street			= "One Apple Park Way"
city			= "Cupertino"
code			= "CA 95014"
country			= "USA"
%%%

.# Abstract

This document specifies a protocol for advertising and discovering devices and services while preserving privacy and confidentiality.

{mainmatter}

# Introduction

Advertising and discovering devices and services on the network can leak a lot of information about a device or person, such as their name, the types of services they provide or use, and persistent identifiers. This information can be used to identify and track a person's location and daily routine (e.g. buys coffee every morning at 8 AM at Starbucks on Main Street). It can also reveal intimate details about a person's behavior and medical conditions, such as discovery requests for a glucose monitor, possibly indicating diabetes.

This document specifies a system for advertising and discovery of devices and services while preserving privacy and confidentiality.

This document does not specify how keys are provisioned. Provisioning keys is complex enough to justify its own document(s). This document assumes each peer has a long-term asymmetric key pair (LTPK and LTSK) and communicating peers have each other's long-term asymmetric public key (LTPK).

# Conventions and Terminology

The key words "**MUST**", "**MUST NOT**", "**REQUIRED**", "**SHALL**", "**SHALL NOT**",
"**SHOULD**", "**SHOULD NOT**", "**RECOMMENDED**", "**MAY**", and "**OPTIONAL**" in this
document are to be interpreted as described in [@!RFC2119].

"**Announcement**"
: Unsolicited multicast message sent to inform friends on the network that you have become available or have updated data.

"**Answer**"
: Solicited unicast message sent in response to a query to provide info or indicate the lack of info.

"**Friend**"
: A peer you have a cryptographic relationship with. Specifically, that you have the peer's LTPK.

"**DH/ECDH**"
: Diffie-Hellman key exchange. ECDH is the elliptic curve version of DH.

"**LTPK**"
: Long-term asymmetric public key. Used for verifying signatures.

"**LTSK**"
: Long-term asymmetric secret key. Used for generating signatures.

"**Multicast**"
: This term is used in the generic sense of sending a message that targets 0 or more peers. It's not strictly required to be a UDP packet with a multicast destination address. It could be sent via TCP or some other transport to a router that repeats the message via unicast to each peer.

"**Probe**"
: Unsolicited multicast message sent to find friends on the network.

"**Response**"
: Solicited unicast message sent in response to a probe or announcement.

"**Query**"
: Unsolicited unicast message sent to get specific info from a peer.

"**Unicast**"
: This term is used in the generic sense of sending a message that targets a single peer. It's not strictly required to be a UDP packet with a unicast destination address.

Multi-byte values are encoded from the most significant byte to the least significant byte (big endian).

When multiple items are concatenated together, the symbol "||" (without quotes) between each item is used to indicate this. For example, a combined item of A followed by B followed by C would be written as "A || B || C".

# Protocol

This document uses two techniques to preserve privacy and provide confidentiality. The first is announcing, probing, and responding with only enough info to allow a peer with your public key to detect that it's you while hiding your identity from peers without your public key. This technique uses a fresh random, signed with your private key using a signature algorithm that doesn't reveal your public key. The second technique is to query and answer in a way that only a specific friend can read the data. This uses ephemeral key exchange and symmetric encryption and authentication.

The general flow of the protocol is a device sends multicast probes to discover friend devices on the network. If friend devices are found, it directly communicates with them via unicast queries and answers. Announcements are sent to report availability and when services are added or removed.

Messages use a common header with a flags/type field. This indicates the format of the data after the header. Unknown message types MUST be ignored. Any data beyond the type-specific message body MUST be ignored. Future versions of this document may define additional data and this MUST NOT cause older message parsers to break. Updated formats that break compatibility with older parsers MUST use a new message type.

This protocol avoids explicit version numbers. It's versioned using message types and flags. Flags are used for protocol extensions where a flag can indicate the presence of an optional field. A new message type is used when the old message type structure cannot reasonably be extended without breaking older parsers. For example, if the probe message in this document changed to use a different key type then older parsers would misinterpret the content of the message. A new type MUST be used in this case so it will be ignored by older, compliant parsers.

Message format:
~~~~
 0 1 2 3 4 5 6 7 8 bits
+-----+---------+~~~~~~~~~~~~~~~~~~~~
|Flags|  Type   | Type-specific data
+-----+---------+~~~~~~~~~~~~~~~~~~~~
~~~~
* Flags: Flags for future use. Set to 0 when sending. Ignore when receiving.
* Type:  Message type. See (#message-types).

## Probe {#probe}

A probe is used to discover friends on the network. It provides enough info for a friend to identify the source, but doesn't allow non-friends to identify it. Probe procedure:

1. Generate a fresh ephemeral public key (EPK1) and its corresponding secret key (ESK1).
2. Get the current timestamp (TS1). See Timestamps (#timestamps).
3. Generate the payload as "Probe" || EPK1 || TS1 || "End".
4. Generate a signature of the payload (SIG1) using the prober's long-term secret key (LTSK1).
5. Generate the probe with EPK1, TS1, and SIG1.
6. Send the probe via unicast to the sender of the probe.

When a peer receives a probe, it does the following:

1. Verify TS1. If TS1 is outside the time window the message SHOULD be ignored.
2. Verify SIG1 with the public key of each of its friends. If verification fails for all public keys, ignore the probe.
3. If a verification succeeds for a friend's public key, send a response to that friend.

Message format:
~~~~
      0 1 2 3 4 5 6 7 8 bits
+0   +-----+---------+
     |Flg=0| Type=1  | 1 byte
+1   +-----+---------+---------------+
     | EPK1                          | 32 bytes 
     |                               |
+33  +-------------------------------+
     | TS1                           | 4 bytes
+37  +-------------------------------+
     | SIG1                          | 64 bytes
     |                               |
     |                               |
     +-------------------------------+
+101 Total bytes
~~~~

## Response {#response}

A response is sent to answer a probe and provide keys for subsequent encryption of future queries. Response procedure:

1. Generate a fresh ephemeral public key (EPK2) and its corresponding secret key (ESK2).
2. Perform DH using EPK1 and ESK2 to compute a shared secret.
3. Derive a symmetric session key (SSK2) from the shared secret.
4. Generate the payload as "Response" || EPK2 || EPK1 || TS1 || "End".
5. Generate a signature of the payload (SIG2) using the responder's long-term secret key (LTSK2).
6. Encrypt the signature with SSK2 and a nonce of 1 to generate ESIG2.
7. Generate the response with EPK2 and ESIG2.
8. Send the response via unicast to the sender of the probe.

When the friend that sent the probe receives the response, it does the following:

1. Performs DH using EPK2 and EKS1 to compute a shared secret.
2. Derive a symmetric session key (SSK2) from the shared secret for decryption.
3. Symmetrically verify ESIG2 using SSK2. If this fails, ignore the response.
4. Decrypt ESIG2 to reveal SIG2.
5. Verify SIG2 with the public key of each of its friends. If verification fails for all public keys, ignore the response.
6. Derive a a symmetric session key (SSK1) from the shared secret to encryption. Session keys (SSK1 and SSK2) are used for subsequent communication with the friend.

Key Derivation details:

* SSK1: HKDF-SHA-512 with Salt = "SSK1-Salt", Info = "SSK1-Info", Output size = 32 bytes.
* SSK2: HKDF-SHA-512 with Salt = "SSK2-Salt", Info = "SSK2-Info", Output size = 32 bytes.

Message format:
~~~~
      0 1 2 3 4 5 6 7 8 bits
+0   +-----+---------+
     |Flg=0| Type=2  | 1 byte
+1   +-----+---------+---------------+
     | EPK2                          | 32 bytes 
     |                               |
+33  +-------------------------------+
     | ESIG2                         | 96 bytes
     |                               |
     |                               |
     +-------------------------------+
+129 Total bytes
~~~~

## Announcement {#announcement}

An announcement indicates availability to friends on the network or if it has update(s). It is sent whenever a device joins a network (e.g. joins WiFi, plugged into Ethernet, etc.), its IP address changes, or when it has an update for one or more of its services. Announce procedure:

1. Generate a fresh ephemeral public key (EPK1) and its corresponding secret key (ESK1).
2. Get the current timestamp (TS1). See Timestamps (#timestamps).
3. Generate the payload as "Announcement" || EPK1 || TS1 || "End".
4. Generate a signature of the payload (SIG1) using the announcer's long-term secret key (LTSK1).
5. Generate the announcement with EPK1, TS1, and SIG1.
6. Send the announcement via multicast.

When a peer receives an announcement, it does the following:

1. Verify TS1. If TS1 is outside the time window the message SHOULD be ignored.
2. Verify SIG1 with the public key of each of its friends. If verification fails for all public keys, ignore the announcement.
3. If a verification succeeds for a friend's public key, it knows which friend sent the announcement.

Message format:
~~~~
      0 1 2 3 4 5 6 7 8 bits
+0   +-----+---------+
     |Flg=0| Type=3  | 1 byte
+1   +-----+---------+---------------+
     | EPK1                          | 32 bytes 
     |                               |
+33  +-------------------------------+
     | TS1                           | 4 bytes
+37  +-------------------------------+
     | SIG1                          | 64 bytes
     |                               |
     |                               |
     +-------------------------------+
+101 Total bytes
~~~~

## Query {#query}

A query is sent to request specific info from a friend. Query procedure:

1. Generate query data (MSG1).
2. Get the symmetric session key for the target friend. This is SSK1 for the original prober or SSK2 for the original responder.
3. Encrypt MSG1 with the symmetric session key to generate EMSG1. The nonce is 1 larger than the last nonce used with this symmetric key (e.g. nonce of 2 if this is the first message to this friend after the probe/response).
4. Send the query via unicast to the friend.

When the friend receives a query, it does the following:

1. Symmetrically verify EMSG1 against every active session's key. If this fails for all keys, ignore the query.
2. Decrypt EMSG1 to reveal MSG1.
3. Process the query and possibly send an answer.

Message format:
~~~~
     0 1 2 3 4 5 6 7 8 bits
+0  +-----+---------+
    |Flg=0| Type=4  | 1 byte
+1  +-----+---------+--------------+
    | EMSG1 (Encrypted query data) | n + 16 bytes 
    |                              |
    +------------------------------+
+17 + n Total bytes
~~~~

## Answer {#answer}

An answer is sent in response to a query from a friend. Answer procedure:

1. Generate answer data (MSG2).
2. Get the querying friend's symmetric session key. This is SSK1 for the original prober or SSK2 for the original responder.
3. Encrypt MSG2 the symmetric session key to generate EMSG2. The nonce is 1 larger than the last nonce used with this symmetric key (e.g. nonce of 2 if this is the first message to this friend after the probe/response).
4. Send the answer via unicast to the querying friend.

When the querying friend receives the answer, it does the following:

1. Symmetrically verify EMSG2 against every active session's key. If this fails for all keys, ignore the answer.
2. Decrypt EMSG2 to reveal MSG2.
3. Process the answer.

Message format:
~~~~
     0 1 2 3 4 5 6 7 8 bits
+0  +-----+---------+
    |Flg=0| Type=5  | 1 byte
+1  +-----+---------+--------------+
    | EMSG2 (Encrypted query data) | n + 16 bytes 
    |                              |
    +------------------------------+
+17 + n Total bytes
~~~~

# Timestamps {#timestamps}

A timestamp in this document is the number of seconds since 1970-01-01 00:00:00 UTC (i.e. Unix Epoch Time). Timestamps sent in messages SHOULD be randomized by +/- 30 seconds to reduce the fingerprinting ability of observers. A timestamp of 0 means the sender doesn't know the current time (e.g. lacks a battery-backed RTC and access to an NTP server). Receivers MAY use a timestamp of 0 to decide whether to enforce time window restrictions. This can allow discovery in situations where one or more devices don't know the current time (e.g. location without Internet access).

A timestamp is considered valid if it's within N seconds of the current time of the receiver. The RECOMMENDED value of N is 900 seconds (15 minutes) to allow peers to remain discoverable even after a large amount of clock drift.

# Implicit Nonces

The nonces in this document are integers that increment by 1 for each encryption. Nonces are never included in any message. Including nonces in messages would enable senders to be easily tracked by their predictable nonce sequence. This may seem futile if other layers of the system also leak trackable identifiers, such as IP addresses, but this document tries to avoid introducing any new privacy leaks in anticipation of leaks by other layers eventually being fixed. Random nonces could avoid tracking, but make replay protection difficult by requiring the receiver to remember previously received messages to detect a replay.

One issue with implicit nonces and replay protection in general is handling lost messages. Message loss and reordering is expected and shouldn't cause complete failure. Accepting nonces within N of the expected nonce enables recovery from some loss and reordering. When a message is received, the expected nonce is checked first and then nonce + 1, nonce - 1, up to nonce +/- N. The RECOMMENDED value of N is 8 as a balance between privacy, robustness, and performance.

# Re-keying and Limits

Re-keying is a hedge against key compromise. The underlying algorithms have limits that far exceed reasonable usage (e.g. 96-bit nonces), but if a key was revealed then we want to reduce the damage by periodically re-keying.

Probes are periodically re-sent with a new ephemeral public key in case the previous key pair was compromised. The RECOMMENDED maximum probe ephemeral public key lifetime is 20 hours. This is close to 1 day since people often repeat actions on a daily basis, but with some leeway for natural variations. If a probe ephemeral public key is re-generated for other reasons, such as joining a WiFi network, the refresh timer is reset.

Session keys are periodically re-key'd in case a symmetric key was compromised. The RECOMMENDED maximum session key lifetime is 20 hours or 1000 messages, whichever comes first. This uses the same close-to-a-day reasoning as probes, but adds a maximum number of messages to reduce the potential for exposure when many messages are being exchanged. Responses SHOULD be throttled if it appears that a peer is making an excessive number of requests since this may indicate the peer is probing for weaknesses (e.g. timing attacks, ChopChop-style attacks).

# Message Types {#message-types}

|Name			|Type	|Description
|:--------------|:------|:----------
|Invalid		|0		|Invalid message type. Avoids misinterpreting zeroed memory.
|Probe			|1		|See (#probe).
|Response		|2		|See (#response).
|Announcement	|3		|See (#announcement).
|Query			|4		|See (#query).
|Answer			|5		|See (#answer).
|Reserved		|6-31	|Reserved. Don't send. Ignore if received.

# Message Fields {#message-fields}

|Name			|Description
|:--------------|:----------
|EPK1/EPK2		|Ephemeral Public Key. 32-byte Curve25519 public key.
|TS1			|Timestamp. 4-byte timestamp. See Timestamps (#timestamps).
|SIG1/SIG2		|Signature. 64-byte Ed25519 signature.
|ESIG1/ESIG2	|Encrypted signature. Ed25519 signature encrypted with ChaCha20-Poly1305. Formatted as the 64-byte encrypted portion followed by a 16-byte MAC (96 bytes total).
|EMSG1/EMSG2	|Encrypted message. Message encrypted with ChaCha20-Poly1305. Formatted as the N-byte encrypted portion followed by a 16-byte MAC (N + 16 bytes total).

# Security Considerations

* Privacy considerations are specified in draft-cheshire-dnssd-privacy-considerations.
* Ephemeral key exchange uses elliptic curve Diffie-Hellman (ECDH) with Curve25519 as specified in [@!RFC7748].
* Signing and verification uses Ed25519 as specified in [@!RFC8032].
* Symmetric encryption uses ChaCha20-Poly1305 as specified in [@!RFC7539].
* Key derivation uses HKDF as specified in [@!RFC5869] with SHA-512 as the hash function.
* Randoms and randomization MUST use cryptographic random numbers.

Information leaks may still be possible in some situations. For example, an attacker could capture probes from a peer they've identified and replay them elsewhere within the allowed timestamp window. This could be used to determine if their friend is present on that network.

The network infrastructure may leak identifiers in the form of persistent IP addresses and MAC addresses. Mitigating this requires changes at lower levels of the network stack, such as periodically changing IP addresses and MAC addresses.

# IANA Considerations

* A multicast UDP port number would need to be allocated by IANA.
* Message types defined by this document are intended to be managed by IANA.

# To Do

The following are some of the things that still need to be specified and decided:

* Figure out how sleep proxies might work with this protocol.
* Define probe and announcement random delays to reduce collisions.
* Describe when to use the same EPK2 in a response to reduce churn on probe/response collisions.
* Consider randomly answering probes for non-friends to mask real friends.
* Design public service protocol to allow pairing.
* Recommend random delays before sending responses to mask friend list sizes.

{backmatter}
