	//
	//  FlowWebSocketFrameHandler.swift
	//  Flow
	//

import Foundation
import NIOCore
import NIOWebSocket

	/// Low-level NIO handler that decodes websocket frames from the Flow access node.
	///
	/// Decoded envelopes are delivered two ways:
	///   1. Via `onEnvelope` — routes into FlowWebSocketCenter's shared AsyncStream
	///      so callers of `subscribeToTransactionStatus` receive typed responses.
	///   2. Via Flow.shared.publisher — preserves existing high-level event fan-out.
final class FlowWebSocketFrameHandler: ChannelInboundHandler, @unchecked Sendable {

	typealias InboundIn = WebSocketFrame

		/// Injected by FlowNIOWebSocketClient; feeds FlowWebSocketCenter's envelope bus.
	private let onEnvelope: (@Sendable (Flow.WebSocketEnvelope) -> Void)?

	init(onEnvelope: (@Sendable (Flow.WebSocketEnvelope) -> Void)? = nil) {
		self.onEnvelope = onEnvelope
	}

	func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		let frame = self.unwrapInboundIn(data)

		guard frame.opcode == .text else {
			context.fireChannelRead(data)
			return
		}

		var buffer = frame.unmaskedData
		guard let bytes = buffer.readBytes(length: buffer.readableBytes) else {
			context.fireChannelRead(data)
			return
		}

		do {
			let envelope = try JSONDecoder().decode(Flow.WebSocketEnvelope.self, from: Data(bytes))

				// 1. Feed the AsyncStream bus so subscription streams receive it.
			onEnvelope?(envelope)

				// 2. Also publish high-level events via Flow.Publisher (existing behaviour).
			handleEnvelope(envelope, context: context)
		} catch {
			context.fireErrorCaught(error)
		}
	}

	func errorCaught(context: ChannelHandlerContext, error: Error) {
		_Concurrency.Task {
			await Flow.shared.publisher.publishError(error)
		}
		context.close(promise: nil)
	}

		// MARK: - Private

	private func handleEnvelope(
		_ envelope: Flow.WebSocketEnvelope,
		context: ChannelHandlerContext
	) {
		guard envelope.topic == .transactionStatuses,
			  let payload = envelope.transactionStatusPayload else {
			return
		}

		do {
			let result = try payload.asTransactionResult()
			_Concurrency.Task {
				await Flow.shared.publisher.publishTransactionStatus(
					id: result.blockId,
					status: result
				)
			}
		} catch {
			context.fireErrorCaught(error)
		}
	}
}
