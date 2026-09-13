//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-libp2p open source project
//
// Copyright (c) 2022-2026 swift-libp2p project authors
// Licensed under MIT
//
// See LICENSE for license information
// See CONTRIBUTORS for the list of swift-libp2p project authors
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import LibP2P

/// Encodes a `MPLEXFrame` onto the wire as `uVarInt(header) || uVarInt(length) || payload`, where
/// `header = streamID << 3 | flag`.
internal class MPLEXFrameEncoder: MessageToByteEncoder {
    public typealias OutboundIn = MPLEXFrame

    public init() {}

    public func encode(data: MPLEXFrame, out: inout ByteBuffer) throws {
        let header = data.streamID.id << 3 | data.flag.rawValue
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
            out.writeVarInt(header)
            out.writeVarIntLengthPrefixed(chunk)
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

    public init() {}

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // If we don't have a header yet, we need to read one
        if self.headerValue == nil {
            do {
                self.headerValue = try buffer.readVarInt()
            } catch {
                throw Errors.invalidVarInt
            }
        }
        guard let headerValue = self.headerValue else {
            // Not enough bytes to read the MPLEXHeader. Ask for more.
            return .needMoreData
        }

        // Read the length prefixed payload.
        let messageBytes: ByteBuffer
        do {
            guard let body = try buffer.readVarIntLengthPrefixedSlice(limit: Self.maxMessageSize) else {
                // Not enough bytes in the buffer to satisfy the read. Ask for more.
                return .needMoreData
            }
            messageBytes = body
        } catch VarIntError.exceedsLimit {
            throw Errors.messageTooLarge(
                length: try Self.announcedLength(of: buffer),
                max: Self.maxMessageSize
            )
        } catch {
            throw Errors.invalidVarInt
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

        // We don't need the header now.
        self.headerValue = nil

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

    /// Attempts to read the length prefix so `messageTooLarge` can provide the length.
    ///
    /// - Throws: `invalidVarInt` when the prefix can't be decoded on its own.
    private static func announcedLength(of buffer: ByteBuffer) throws -> UInt64 {
        guard let prefix = try? buffer.getVarInt(at: buffer.readerIndex) else {
            throw Errors.invalidVarInt
        }
        return prefix.value
    }

    public enum Errors: Error, Equatable {
        /// The lower 3 bits of a header did not correspond to a known mplex flag.
        case invalidMPLEXFlag
        /// A VarInt was malformed, it overflowed 64 bits, or it was non-minimally encoded.
        case invalidVarInt
        /// A frame advertised a payload larger than `maxMessageSize`.
        case messageTooLarge(length: UInt64, max: UInt64)
    }
}
