//
//  MPLEXFrameCoders.swift
//  
//
//  Created by Brandon Toms on 3/2/22.
//

import LibP2P
import VarInt

/// TODO: This should be a byteToMessageDecoder
public final class MPLEXFrameDecoder:ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = MPLEXFrame
    
    private var partialResultsBuffer:[UInt8] = []
    private weak var _context:ChannelHandlerContext! = nil
    private var logger:Logger
    
    init(logger:Logger) {
        self.logger = logger
    }
    
    public func handlerAdded(context: ChannelHandlerContext) {
        logger.trace("FrameDecoder Added")
        self._context = context
    }

    public func handlerRemoved(context: ChannelHandlerContext) {
        logger.trace("FrameDecoder Removed")
        self._context = nil
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = self.unwrapInboundIn(data)
        
        //print("Inbound MPLEXFrame: \(Array<UInt8>(identifiedData.payload.readableBytesView).asString(base: .base16))")
        
        guard let frames = try? mplexDecodeAllPayloads(buffer) else {
            logger.error("Failed to decode MPLEX headers on incoming data")
//            logger.error("\(identifiedData.payload.debugDescription)")
            return
        }
        
        for frame in frames {
            guard let flag = MPLEXFlag(rawValue: frame.flag) else { continue }
            let streamID = MPLEXStreamID(id: frame.id, flag: flag)
            let payload = context.channel.allocator.buffer(bytes: frame.payload) //IdentifiedPayload(peer: identifiedData.peer, multiaddr: identifiedData.multiaddr, payload: context.channel.allocator.buffer(bytes: frame.payload))
            logger.trace("Inbound MPLEXFrame[\(streamID.id)][\(streamID.initiator ? "Initiator" : "Listener")][\(flag)]: \(Array<UInt8>(payload.readableBytesView).asString(base: .base16))")
            let out:MPLEXFrame
            switch flag {
            case .NewStream:
                out = MPLEXFrame(
                    streamID: streamID,
                    payload: .newStream
                )
            case .MessageReceiver, .MessageInitiator:
                out = MPLEXFrame(
                    streamID: streamID,
                    payload: .inboundData( payload )
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
            context.fireChannelRead(self.wrapInboundOut(out))
        }
    }
    
    public func channelReadComplete(context: ChannelHandlerContext) {
        context.fireChannelReadComplete()
    }

    public func channelActive(context: ChannelHandlerContext) {
        context.fireChannelActive()
    }

    public func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("FrameDecoder: Error: \(error)")
        context.fireErrorCaught(error)
    }
    
    private func mplexDecodeAllPayloads(_ bytes:ByteBuffer) throws -> [(id:UInt64, flag:UInt64, payload:[UInt8])] {
        var b = Array<UInt8>(bytes.readableBytesView)
        
        var messages:[(id:UInt64, flag:UInt64, payload:[UInt8])] = []
        
        if !partialResultsBuffer.isEmpty {
            b = partialResultsBuffer + b
            partialResultsBuffer = []
        }
        
        while b.count > 0 {
            guard let header = try? mplexDecode(b) else { // Is this logic sound?
                partialResultsBuffer = b; break;
            }
            //self.logger.debug("Header: \(header)")
            let endIndex = header.offset + header.length
            let startIndex = header.offset //- 1 //If we subtract one (we can decode our Identify messages)
            guard b.count >= endIndex else { /*logger.error("Partial Read Encountered (B:\(b.count), EI:\(endIndex))"); partialResultsBuffer = b;*/ break }
            messages.append( (id: header.id, flag: header.flag, payload: Array<UInt8>(b[startIndex..<endIndex]) ) )
            b.removeFirst(endIndex)
        }
        
        return messages
    }
    
    private func mplexDecodeFirstPayload(_ bytes:[UInt8]) throws -> (id:UInt64, flag:MPLEXFlag, bytes:[UInt8], leftover:[UInt8]?) {
        let header = try mplexDecode(bytes)
        guard let flag = MPLEXFlag(rawValue: header.flag) else {
            throw MuxerError.custom("Invalid Flag parsed from Mplex Header: '\(header.flag)'")
        }
        let endIndex = header.offset + header.length
        return (
            id: header.id,
            flag: flag,
            bytes: Array<UInt8>(bytes[header.offset..<endIndex]),
            leftover: bytes.count > endIndex ? Array<UInt8>(bytes.dropFirst(endIndex)) : nil
        )
    }
    
    private func mplexDecode(_ bytes:[UInt8]) throws -> (id:UInt64, flag:UInt64, offset:Int, length:Int) {
        let h = uVarInt(bytes)
        guard h.bytesRead > 0 else { throw MuxerError.custom("Failed to decode header uVarInt") }
        let length = uVarInt(Array<UInt8>(bytes.dropFirst(h.bytesRead)))
        guard length.bytesRead > 0 else { throw MuxerError.custom("Failed to decode length prefix mplex message") }
        return (h.value >> 3, h.value & 7, h.bytesRead + length.bytesRead, Int(length.value))
    }
}


public final class MPLEXFrameEncoder:ChannelOutboundHandler {
    public typealias OutboundIn = MPLEXFrame
    public typealias OutboundOut = ByteBuffer
    
    private var logger:Logger
    
    init(logger:Logger) {
        self.logger = logger
    }
    
    public func handlerAdded(context: ChannelHandlerContext) {
        logger.trace("FrameEncoder Added")
    }

    public func handlerRemoved(context: ChannelHandlerContext) {
        logger.trace("FrameEncoder Removed")
    }

    public func channelActive(context: ChannelHandlerContext) {
        context.fireChannelActive()
    }

    public func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }
    
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let frameIn = self.unwrapOutboundIn(data)
        //logger.trace("FrameEncoder Writing Frame for Stream[\(frameIn.streamID)]")
        let payloadOut = mplexEncodePayload(id: frameIn.streamID.id, flag: frameIn.flag.rawValue, payload: frameIn.payload.bytes, context: context)
        
        logger.trace("Outbound MPLEXFrame[\(frameIn.streamID.id)][\(frameIn.streamID.initiator ? "Initiator" : "Listener")][\(frameIn.flag)]: \(Array<UInt8>(payloadOut.readableBytesView).asString(base: .base16))")
        
        context.write( wrapOutboundOut(payloadOut), promise: nil)
    }
    
    // Flush it out. This can make use of gathering writes if multiple buffers are pending
    public func channelWriteComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("FrameEncoder: Error: \(error)")
        //context.close(promise: nil)
        context.fireErrorCaught(error)
    }
    
    private func mplexEncodePayload(id:UInt64, flag:UInt64, payload:[UInt8], context:ChannelHandlerContext) -> ByteBuffer {
        // Encode Payload Length
        let length = putUVarInt(UInt64(payload.count))
        let header = putUVarInt(id << 3 | flag)
        
        return context.channel.allocator.buffer(bytes: header + length + payload)
    }
    
}

//public final class MPLEXFrameDecoder2:ByteToMessageDecoder {
//    public typealias InboundOut = MPLEXFrame
//
//    private var messageLength: Int? = nil
//
//    public init() {}
//
//    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
//        // If we don't have a length, we need to read one
//        if self.messageLength == nil {
//            self.messageLength = buffer.readVarint()
//        }
//        guard let length = self.messageLength else {
//            // Not enough bytes to read the message length. Ask for more.
//            return .needMoreData
//        }
//
//        // See if we can read this amount of data.
//        guard let messageBytes = buffer.readSlice(length: length) else {
//            // not enough bytes in the buffer to satisfy the read. Ask for more.
//            return .needMoreData
//        }
//
//        // We don't need the length now.
//        self.messageLength = nil
//
//        // Send the message's bytes up the pipeline to the next handler.
//        context.fireChannelRead(self.wrapInboundOut(messageBytes))
//
//        // We can keep going if you have more data.
//        return .continue
//    }
//
//    public func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
//        return try decode(context: context, buffer: &buffer)
//    }
//}
