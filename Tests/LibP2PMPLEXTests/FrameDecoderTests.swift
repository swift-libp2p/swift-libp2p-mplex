//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-libp2p open source project
//
// Copyright (c) 2022-2025 swift-libp2p project authors
// Licensed under MIT
//
// See LICENSE for license information
// See CONTRIBUTORS for the list of swift-libp2p project authors
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import LibP2P
import NIOTestUtils
import Testing

@testable import LibP2PMPLEX

@Suite("Libp2p MPLEX Tests")
struct LibP2PMPLEXTests {

    /// A few newStream MPLEXFrames
    @Test func testMPLEXFrameDecoderNewStreams() throws {
        let inboundData: [UInt8] = [
            0x88, 0x01, 0x02, 0x31, 0x37, 0x98, 0x01, 0x02, 0x31, 0x39, 0xa8, 0x01, 0x02, 0x32, 0x31,
        ]

        let channel = EmbeddedChannel()
        let inbound = channel.allocator.buffer(bytes: inboundData)

        //( id: 17, type: 0, data: "17".data(using: .utf8)! ),
        //( id: 19, type: 0, data: "19".data(using: .utf8)! ),
        //( id: 21, type: 0, data: "21".data(using: .utf8)! )
        let exepectedInOuts = [
            (
                inbound,
                [
                    MPLEXFrame(streamID: MPLEXStreamID(id: 17, flag: .NewStream), payload: .newStream),
                    MPLEXFrame(streamID: MPLEXStreamID(id: 19, flag: .NewStream), payload: .newStream),
                    MPLEXFrame(streamID: MPLEXStreamID(id: 21, flag: .NewStream), payload: .newStream),
                ]
            )
        ]

        #expect(throws: Never.self) {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                inputOutputPairs: exepectedInOuts,
                decoderFactory: { MPLEXFrameDecoder() }
            )
        }
    }

    /// This is a recording of all the inbound bytes sent during an echo request using GO's echo example
    /// - Multistream, PlaintextV2, MPLEX
    /// - /echo/1.0.0 protocol
    @Test func testMPLEXFrameDecoderGoEchoReplay() throws {
        let inboundHex =
            "0001300224132f6d756c746973747265616d2f312e302e300a0f2f697066732f69642f312e302e300a0114132f6d756c746973747265616d2f312e302e300a0914132f6d756c746973747265616d2f312e302e300a010d0c2f6563686f2f312e302e300a09100f2f697066732f69642f312e302e300a09c308c1080aab02080012a60230820122300d06092a864886f70d01010105000382010f003082010a0282010100bc012529f27a56372766b242283c295ca6e01245b4ef6a4d7f6dea098053ae9ebbe96690122e738da9987e24360a65c760455ac66505d6809d964a2c0847edcde8e38d58e671ca9d5f0103f8d200b150883dc1dd4f696e0655d12768b681070f2d0688e97b7d7fba2997d83c28af843662a7dac16f847bf797a5a56d6c00856101edd8a424ea478b1223653d666c6c27ab68767491be63c7d4edade0e5ea81d3a6728bf5c967a0a3cc03a4fd080e9b575c91be1b4bace26a6203c03df9282cb684e4428a235ed45b8e9e59bd743766e970adf0778ed46278b30010c4935d1c40bd6b969ebabf118e3ae152eb7dafa1557b04cfa5d6985b02222a9933a680f42502030100011208047f0000010627101a132f7032702f69642f64656c74612f312e302e301a0e2f697066732f69642f312e302e301a132f697066732f69642f707573682f312e302e301a102f697066732f70696e672f312e302e301a0b2f6563686f2f312e302e302208047f00000106e0ad2a0a697066732f302e312e3032246769746875622e636f6d2f6c69627032702f676f2d6c69627032702f6578616d706c657342f1040aab02080012a60230820122300d06092a864886f70d01010105000382010f003082010a0282010100bc012529f27a56372766b242283c295ca6e01245b4ef6a4d7f6dea098053ae9ebbe96690122e738da9987e24360a65c760455ac66505d6809d964a2c0847edcde8e38d58e671ca9d5f0103f8d200b150883dc1dd4f696e0655d12768b681070f2d0688e97b7d7fba2997d83c28af843662a7dac16f847bf797a5a56d6c00856101edd8a424ea478b1223653d666c6c27ab68767491be63c7d4edade0e5ea81d3a6728bf5c967a0a3cc03a4fd080e9b575c91be1b4bace26a6203c03df9282cb684e4428a235ed45b8e9e59bd743766e970adf0778ed46278b30010c4935d1c40bd6b969ebabf118e3ae152eb7dafa1557b04cfa5d6985b02222a9933a680f4250203010001120203011a3a0a22122069849906f7fc9053e2e7d7331d701fe700cfedcc0438f77b4154ce4bf65b4b6c108892d3f2b7b0f0f5161a0a0a08047f0000010627102a80025f22482bf15d571a5e5c1938bbf4d7614c8884da53ee98b28312a75c18fc79d357a4ccf6209d1c53e6b21db94ebedadec4537230d06cbed04bdbc75582cca88d03b0cae5928c228ec7a356de046d3743efcc7148c25b03335bac7ffd26ead0cd468d1e31a7df3854f0fbcacb7e9e168b5d1bc6484aeeaa19ab1400e346f4074ef5050502d47698a139f3eed6f93ea9380135c65b8a9524c979dd65d319fbdb52cb20f5d4c465308d5297b5077b413178c2664cf13c83279fdfdcebb0044e0778df7dadfe66d372bc14b9c8000368706f76ee1d08508fecaedf81deaabe3c9fff225d97241183eb07f93e2f4920cb58c6ff750127db0d858b3e943a89d18a11160b00011348656c6c6f205377696674204c69625032500a03000400"

        let channel = EmbeddedChannel()
        let inbound = channel.allocator.buffer(bytes: [UInt8](hex: inboundHex))

        let exepectedInOuts = [
            (
                inbound,
                [
                    /// Go opening an Identify stream with ID: 0
                    MPLEXFrame(streamID: MPLEXStreamID(id: 0, flag: .NewStream), payload: .newStream),
                    /// Go sending the multistream/1.0.0 and /ipfs/id/1.0.0 negotiation messages
                    MPLEXFrame(
                        streamID: MPLEXStreamID(id: 0, flag: .MessageInitiator),
                        payload: .inboundData(
                            ByteBuffer(
                                bytes: [UInt8](
                                    hex: "132f6d756c746973747265616d2f312e302e300a0f2f697066732f69642f312e302e300a"
                                )
                            )
                        )
                    ),
                    /// Go responding to our new Stream 0 and mss request with a /multistream/1.0.0 response
                    MPLEXFrame(
                        streamID: MPLEXStreamID(id: 0, flag: .MessageReceiver),
                        payload: .inboundData(
                            ByteBuffer(bytes: [UInt8](hex: "132f6d756c746973747265616d2f312e302e300a"))
                        )
                    ),
                    /// Go responding to our new Stream 1 and mss request with a /multistream/1.0.0 response
                    MPLEXFrame(
                        streamID: MPLEXStreamID(id: 1, flag: .MessageReceiver),
                        payload: .inboundData(
                            ByteBuffer(bytes: [UInt8](hex: "132f6d756c746973747265616d2f312e302e300a"))
                        )
                    ),
                    /// Go responding to our /echo/1.0.0 protocol negotiation with an /echo/1.0.0
                    MPLEXFrame(
                        streamID: MPLEXStreamID(id: 0, flag: .MessageReceiver),
                        payload: .inboundData(ByteBuffer(bytes: [UInt8](hex: "0c2f6563686f2f312e302e300a")))
                    ),
                    /// Go responding to our /ipfs/id/1.0.0 protocol negotiation with an /ipfs/id/1.0.0
                    MPLEXFrame(
                        streamID: MPLEXStreamID(id: 1, flag: .MessageReceiver),
                        payload: .inboundData(ByteBuffer(bytes: [UInt8](hex: "0f2f697066732f69642f312e302e300a")))
                    ),
                    /// Go responding with their ID payload
                    MPLEXFrame(
                        streamID: MPLEXStreamID(id: 1, flag: .MessageReceiver),
                        payload: .inboundData(
                            ByteBuffer(
                                bytes: [UInt8](
                                    hex:
                                        "c1080aab02080012a60230820122300d06092a864886f70d01010105000382010f003082010a0282010100bc012529f27a56372766b242283c295ca6e01245b4ef6a4d7f6dea098053ae9ebbe96690122e738da9987e24360a65c760455ac66505d6809d964a2c0847edcde8e38d58e671ca9d5f0103f8d200b150883dc1dd4f696e0655d12768b681070f2d0688e97b7d7fba2997d83c28af843662a7dac16f847bf797a5a56d6c00856101edd8a424ea478b1223653d666c6c27ab68767491be63c7d4edade0e5ea81d3a6728bf5c967a0a3cc03a4fd080e9b575c91be1b4bace26a6203c03df9282cb684e4428a235ed45b8e9e59bd743766e970adf0778ed46278b30010c4935d1c40bd6b969ebabf118e3ae152eb7dafa1557b04cfa5d6985b02222a9933a680f42502030100011208047f0000010627101a132f7032702f69642f64656c74612f312e302e301a0e2f697066732f69642f312e302e301a132f697066732f69642f707573682f312e302e301a102f697066732f70696e672f312e302e301a0b2f6563686f2f312e302e302208047f00000106e0ad2a0a697066732f302e312e3032246769746875622e636f6d2f6c69627032702f676f2d6c69627032702f6578616d706c657342f1040aab02080012a60230820122300d06092a864886f70d01010105000382010f003082010a0282010100bc012529f27a56372766b242283c295ca6e01245b4ef6a4d7f6dea098053ae9ebbe96690122e738da9987e24360a65c760455ac66505d6809d964a2c0847edcde8e38d58e671ca9d5f0103f8d200b150883dc1dd4f696e0655d12768b681070f2d0688e97b7d7fba2997d83c28af843662a7dac16f847bf797a5a56d6c00856101edd8a424ea478b1223653d666c6c27ab68767491be63c7d4edade0e5ea81d3a6728bf5c967a0a3cc03a4fd080e9b575c91be1b4bace26a6203c03df9282cb684e4428a235ed45b8e9e59bd743766e970adf0778ed46278b30010c4935d1c40bd6b969ebabf118e3ae152eb7dafa1557b04cfa5d6985b02222a9933a680f4250203010001120203011a3a0a22122069849906f7fc9053e2e7d7331d701fe700cfedcc0438f77b4154ce4bf65b4b6c108892d3f2b7b0f0f5161a0a0a08047f0000010627102a80025f22482bf15d571a5e5c1938bbf4d7614c8884da53ee98b28312a75c18fc79d357a4ccf6209d1c53e6b21db94ebedadec4537230d06cbed04bdbc75582cca88d03b0cae5928c228ec7a356de046d3743efcc7148c25b03335bac7ffd26ead0cd468d1e31a7df3854f0fbcacb7e9e168b5d1bc6484aeeaa19ab1400e346f4074ef5050502d47698a139f3eed6f93ea9380135c65b8a9524c979dd65d319fbdb52cb20f5d4c465308d5297b5077b413178c2664cf13c83279fdfdcebb0044e0778df7dadfe66d372bc14b9c8000368706f76ee1d08508fecaedf81deaabe3c9fff225d97241183eb07f93e2f4920cb58c6ff750127db0d858b3e943a89d18a1116"
                                )
                            )
                        )
                    ),
                    /// Go requesting the /ipfs/id/1.0.0 stream be closed
                    MPLEXFrame(streamID: MPLEXStreamID(id: 1, flag: .CloseReceiver), payload: .close),
                    /// Go echoing our "Hello Swift Libp2p" message
                    MPLEXFrame(
                        streamID: MPLEXStreamID(id: 0, flag: .MessageReceiver),
                        payload: .inboundData(ByteBuffer(bytes: [UInt8](hex: "48656c6c6f205377696674204c69625032500a")))
                    ),
                    /// Go requesting the /echo/1.0.0 stream be closed
                    MPLEXFrame(streamID: MPLEXStreamID(id: 0, flag: .CloseReceiver), payload: .close),
                    /// Go responding to our /ipfs/id/1.0.0 close request
                    MPLEXFrame(streamID: MPLEXStreamID(id: 0, flag: .CloseInitiator), payload: .close),
                ]
            )
        ]

        #expect(throws: Never.self) {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                inputOutputPairs: exepectedInOuts,
                decoderFactory: { MPLEXFrameDecoder() }
            )
        }
    }

    // MARK: - Malformed input hardening

    /// A malformed (over-long) header varint must be rejected with a thrown error rather than
    /// crashing the process. Regression test for the previous `fatalError` on varint overflow,
    /// which allowed a remote peer to take down the whole connection/process.
    @Test func testOversizedVarintThrowsInsteadOfCrashing() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(MPLEXFrameDecoder()))
        // 10 continuation bytes: a varint can never be this long for a valid mplex header.
        let malformed = channel.allocator.buffer(bytes: [UInt8](repeating: 0x80, count: 10))

        #expect(throws: MPLEXFrameDecoder.Errors.invalidVarInt) {
            try channel.writeInbound(malformed)
        }

        _ = try? channel.finish()
    }

    /// A frame advertising a payload larger than the 1 MiB spec maximum must be rejected before
    /// its payload is buffered, preventing unbounded memory growth from a hostile peer.
    @Test func testOverSizedMessageIsRejected() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(MPLEXFrameDecoder()))

        // header: streamID 0, flag NewStream (0)  -> varint [0x00]
        // length: 1 MiB + 1 (1_048_577)           -> varint [0x81, 0x80, 0x40]
        let oversized = channel.allocator.buffer(bytes: [0x00, 0x81, 0x80, 0x40])

        #expect(throws: MPLEXFrameDecoder.Errors.messageTooLarge(length: (1 << 20) + 1, max: 1 << 20)) {
            try channel.writeInbound(oversized)
        }

        _ = try? channel.finish()
    }

    /// A frame at exactly the 1 MiB maximum is valid and must decode successfully.
    @Test func testMaxSizedMessageIsAccepted() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(MPLEXFrameDecoder()))

        let max = Int(MPLEXFrameDecoder.maxMessageSize)  // 1 MiB
        // header: streamID 1, flag MessageInitiator (2) -> (1 << 3 | 2) = 10 -> varint [0x0a]
        // length: 1 MiB (1_048_576)                     -> varint [0x80, 0x80, 0x40]
        var bytes: [UInt8] = [0x0a, 0x80, 0x80, 0x40]
        bytes.append(contentsOf: [UInt8](repeating: 0xab, count: max))
        let inbound = channel.allocator.buffer(bytes: bytes)

        try channel.writeInbound(inbound)

        let decoded = try #require(try channel.readInbound(as: MPLEXFrame.self))
        #expect(decoded.streamID.id == 1)
        if case .inboundData(let payload) = decoded.payload {
            #expect(payload.readableBytes == max)
        } else {
            Issue.record("Expected inboundData payload, got \(decoded.payload)")
        }

        _ = try? channel.finish()
    }

    /// An unknown flag (the 3-bit flag field only defines values 0...6) must be rejected.
    @Test func testInvalidFlagThrows() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(MPLEXFrameDecoder()))
        // header: streamID 0, flag 7 (undefined) -> varint [0x07]; length 0 -> [0x00]
        let invalid = channel.allocator.buffer(bytes: [0x07, 0x00])

        #expect(throws: MPLEXFrameDecoder.Errors.invalidMPLEXFlag) {
            try channel.writeInbound(invalid)
        }

        _ = try? channel.finish()
    }

    // MARK: - Encoder round-trips

    /// Round-trips control frames through the encoder and decoder to lock in that `close` and
    /// `reset` map to distinct wire flags and decode back to the correct payload. This also
    /// provides the encoder's first test coverage.
    ///
    /// - Note: We compare the numeric stream ID and payload rather than the whole frame, because
    ///   the initiator flag is intentionally sender-relative on the wire: encoding uses the
    ///   local perspective and decoding reconstructs the peer's, so the boolean flips on a
    ///   single-hop round-trip.
    @Test func testEncodeDecodeRoundTripPreservesPayload() throws {
        let payloads: [MPLEXFrame.FramePayload] = [
            .reset,
            .close,
            .newStream,
            .outboundData(ByteBuffer(bytes: [0x01, 0x02, 0x03, 0x04])),
        ]

        for payload in payloads {
            let frame = MPLEXFrame(streamID: MPLEXStreamID(id: 42, mode: .initiator), payload: payload)

            let encoder = EmbeddedChannel(handler: MessageToByteHandler(MPLEXFrameEncoder()))
            try encoder.writeOutbound(frame)
            let wire = try #require(try encoder.readOutbound(as: ByteBuffer.self))
            _ = try? encoder.finish()

            let decoder = EmbeddedChannel(handler: ByteToMessageHandler(MPLEXFrameDecoder()))
            try decoder.writeInbound(wire)
            let decoded = try #require(try decoder.readInbound(as: MPLEXFrame.self))
            _ = try? decoder.finish()

            #expect(decoded.streamID.id == 42)
            #expect(decoded.payload == expectedInboundPayload(for: payload))
        }
    }

    /// An outbound data payload larger than the 1 MiB spec maximum must be split into multiple
    /// frames (each at or below the limit) that reassemble to the original bytes. Regression test
    /// ensuring we never emit a frame a compliant peer would reset.
    @Test func testOversizedOutboundWriteIsChunked() throws {
        let max = Int(MPLEXFrameDecoder.maxMessageSize)
        let totalSize = max * 2 + 1234  // two full chunks plus a remainder
        let original = [UInt8](repeating: 0xcd, count: totalSize)

        // Encode a single large data frame.
        let encoder = EmbeddedChannel(handler: MessageToByteHandler(MPLEXFrameEncoder()))
        let frame = MPLEXFrame(
            streamID: MPLEXStreamID(id: 9, mode: .initiator),
            payload: .outboundData(ByteBuffer(bytes: original))
        )
        try encoder.writeOutbound(frame)

        var wire = encoder.allocator.buffer(capacity: totalSize)
        while var buffer = try encoder.readOutbound(as: ByteBuffer.self) {
            wire.writeBuffer(&buffer)
        }
        _ = try? encoder.finish()

        // Decode the produced wire bytes back into frames.
        let decoder = EmbeddedChannel(handler: ByteToMessageHandler(MPLEXFrameDecoder()))
        try decoder.writeInbound(wire)

        var reassembled: [UInt8] = []
        var frameCount = 0
        while let decoded = try decoder.readInbound(as: MPLEXFrame.self) {
            frameCount += 1
            #expect(decoded.streamID.id == 9)
            if case .inboundData(let buffer) = decoded.payload {
                #expect(buffer.readableBytes <= max)
                reassembled.append(contentsOf: buffer.readableBytesView)
            } else {
                Issue.record("Expected inboundData payload, got \(decoded.payload)")
            }
        }
        _ = try? decoder.finish()

        #expect(frameCount == 3)
        #expect(reassembled == original)
    }

    /// Maps an outbound payload to the payload the decoder produces for it (the decoder emits
    /// `inboundData` for data frames and carries no bytes for control frames).
    private func expectedInboundPayload(for payload: MPLEXFrame.FramePayload) -> MPLEXFrame.FramePayload {
        switch payload {
        case .outboundData(let buffer):
            return .inboundData(buffer)
        default:
            return payload
        }
    }
}
