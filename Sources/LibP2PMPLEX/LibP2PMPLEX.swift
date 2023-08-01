import NIO
import LibP2P
import LibP2PCore

protocol MessageExtractable {
    func messageBytes() -> ByteBuffer
}

protocol MessageExtractableHandler:ChannelInboundHandler where InboundOut:MessageExtractable { }

public struct MPLEX: MuxerUpgrader {
    
    public static let key:String = MPLEXStreamMultiplexer.protocolCodec
    let application:Application

    public func upgradeConnection(_ conn: Connection, muxedPromise: EventLoopPromise<Muxer>) -> EventLoopFuture<Void> {
        return conn.channel.pipeline.addHandlers(
            [
                ByteToMessageHandler(MPLEXFrameDecoder()),
                MessageToByteHandler(MPLEXFrameEncoder()),
                MPLEXStreamMultiplexer(connection: conn, muxedPromise: muxedPromise, supportedProtocols: [])
            ],
            position: .last
        )
    }
    
    public func printSelf() {
        application.logger.notice("Hi I'm MPLEX v6.7.0")
    }
}

extension Application.MuxerUpgraders.Provider {
    public static var mplex: Self {
        .init { app in
            app.muxers.use {
                MPLEX(application: $0)
            }
        }
    }
}
