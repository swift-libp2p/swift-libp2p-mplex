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
import VarInt

internal class MPLEXFrameEncoder: MessageToByteEncoder {
    public typealias OutboundIn = MPLEXFrame

    public init() {}

    public func encode(data: MPLEXFrame, out: inout ByteBuffer) throws {
        let header = putUVarInt(data.streamID.id << 3 | data.flag.rawValue)
        var payload = data.messageBytes()

        // The mplex spec caps a single frame's payload at 1 MiB. Split larger payloads across
        // multiple frames — each sharing the same header (stream ID + flag) — so we never emit a
        // frame that a spec-compliant peer would reset us for. Data on a stream is a byte stream,
        // so message boundaries carry no semantics and the peer simply reassembles the bytes.
        let maxChunk = Int(MPLEXFrameDecoder.maxMessageSize)

        // Emit at least one frame, even for empty (control) payloads such as close/reset/newStream.
        repeat {
            // `min` keeps the length within bounds, so this force-unwrap is safe.
            let chunk = payload.readSlice(length: min(payload.readableBytes, maxChunk))!
            let length = putUVarInt(UInt64(chunk.readableBytes))
            out.writeBytes(header + length)
            out.writeBytes(chunk.readableBytesView)
        } while payload.readableBytes > 0
    }
}

internal final class MPLEXFrameDecoder: ByteToMessageDecoder {
    public typealias InboundOut = MPLEXFrame

    /// The maximum message payload size permitted by the mplex spec (1 MiB).
    ///
    /// Frames advertising a length larger than this are rejected before we buffer their
    /// payload, preventing a remote peer from forcing unbounded memory growth.
    static let maxMessageSize: UInt64 = 1 << 20

    /// The decoded header value (`streamID << 3 | flag`), retained across `decode` calls
    /// until the full frame is available.
    private var headerValue: UInt64? = nil
    private var msgLength: UInt64? = nil

    public init() {}

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // If we don't have a header yet, we need to read one
        if self.headerValue == nil {
            self.headerValue = try buffer.readVarint()
        }
        guard let headerValue = self.headerValue else {
            // Not enough bytes to read the MPLEXHeader. Ask for more.
            return .needMoreData
        }

        if self.msgLength == nil {
            self.msgLength = try buffer.readVarint()
        }
        guard let msgLength = self.msgLength else {
            // Not enough bytes to read the message length. Ask for more.
            return .needMoreData
        }

        // Reject over-sized frames before buffering their payload. Doing this here (rather
        // than after `readSlice`) means we never wait on / retain more than `maxMessageSize`
        // bytes for a single frame.
        guard msgLength <= Self.maxMessageSize else {
            throw Errors.messageTooLarge(length: msgLength, max: Self.maxMessageSize)
        }

        // See if we can read this amount of data.
        guard let messageBytes = buffer.readSlice(length: Int(msgLength)) else {
            // not enough bytes in the buffer to satisfy the read. Ask for more.
            return .needMoreData
        }

        // Contruct the Flag
        guard let flag = MPLEXFlag(rawValue: headerValue & 7) else { throw Errors.invalidMPLEXFlag }
        // Construct the MPLEXFrame
        let streamID = MPLEXStreamID(id: headerValue >> 3, flag: flag)
        let out: MPLEXFrame
        switch flag {
        case .NewStream:
            out = MPLEXFrame(
                streamID: streamID,
                payload: .newStream
            )
        case .MessageReceiver, .MessageInitiator:
            out = MPLEXFrame(
                streamID: streamID,
                payload: .inboundData(messageBytes)
            )

        case .CloseReceiver, .CloseInitiator:
            out = MPLEXFrame(
                streamID: streamID,
                payload: .close
            )

        case .ResetReceiver, .ResetInitiator:
            out = MPLEXFrame(
                streamID: streamID,
                payload: .reset
            )
        }

        // We don't need the header or length now.
        self.headerValue = nil
        self.msgLength = nil

        // Send the message's bytes up the pipeline to the next handler.
        context.fireChannelRead(self.wrapInboundOut(out))

        // We can keep going if you have more data.
        return .continue
    }

    public func decodeLast(
        context: ChannelHandlerContext,
        buffer: inout ByteBuffer,
        seenEOF: Bool
    ) throws -> DecodingState {
        try decode(context: context, buffer: &buffer)
    }

    public enum Errors: Error, Equatable {
        /// The lower 3 bits of a header did not correspond to a known mplex flag.
        case invalidMPLEXFlag
        /// A varint was malformed: it exceeded the 9-byte / 63-bit maximum for an mplex header.
        case invalidVarInt
        /// A frame advertised a payload larger than `maxMessageSize`.
        case messageTooLarge(length: UInt64, max: UInt64)
    }
}
