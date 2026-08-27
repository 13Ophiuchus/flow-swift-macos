	//
	//  FlowNIOWebSocketClient.swift
	//  Flow
	//

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
@preconcurrency import NIOSSL

public enum FlowWebSocketUpgradeEvent {
	case upgraded
}

	/// NIO-based websocket client for Flow transaction status and topics.
public final class FlowNIOWebSocketClient: @unchecked Sendable {

		// MARK: - State

	public let addresses: [Flow.Address]
	private let accountService: FlowAccountService

	private let group: EventLoopGroup
	private var channel: Channel?
	private let configActor: FlowConfigActor

		/// Called on every successfully decoded inbound envelope.
		/// Wired by FlowWebSocketCenter into its shared AsyncStream.
	private let onEnvelope: (@Sendable (Flow.WebSocketEnvelope) -> Void)?

		// Load from JSON path by default
	public convenience init(
		addressesJSONPath: String,
		group: EventLoopGroup? = nil,
		configActor: FlowConfigActor = .shared,
		onEnvelope: (@Sendable (Flow.WebSocketEnvelope) -> Void)? = nil
	) throws {
		let loaded = try FlowAddressLoader.loadAddressList(fromPath: addressesJSONPath)
		self.init(
			addresses: loaded,
			group: group,
			configActor: configActor,
			onEnvelope: onEnvelope
		)
	}

	public init(
		addresses: [Flow.Address],
		group: EventLoopGroup? = nil,
		configActor: FlowConfigActor = .shared,
		accountService: FlowAccountService = FlowAccountService(),
		onEnvelope: (@Sendable (Flow.WebSocketEnvelope) -> Void)? = nil
	) {
		self.addresses = addresses
		self.accountService = accountService
		self.group = group ?? MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
		self.configActor = configActor
		self.onEnvelope = onEnvelope
	}

	deinit {
		try? group.syncShutdownGracefully()
	}

		// MARK: - Connection

	private var connectTask: _Concurrency.Task<Channel, Error>?

	public func connectIfNeeded() async throws {
		if let channel = channel, channel.isActive {
			return
		}

		if let existing = connectTask {
			channel = try await existing.value
			return
		}

		let chainID = await configActor.chainID
		guard let endpoint = chainID.defaultWebSocketNode, let url = endpoint.url else {
			throw Flow.FError.customError(msg: "No websocket endpoint for chainID \(chainID)")
		}

		let task = _Concurrency.Task { [weak self] () -> Channel in
			guard let self else {
				throw Flow.FError.customError(msg: "Client deallocated during connect")
			}
			return try await self.connectWebSocket(to: url)
		}
		connectTask = task

		defer { connectTask = nil }
		channel = try await task.value

		_Concurrency.Task { [addresses, accountService] in
			do {
				_ = try await accountService.loadAccounts(addresses, maxConcurrent: 4)
			} catch {
					// Log or ignore
			}
		}
	}

	public func disconnect() async {
		if let c = channel {
			_ = try? await c.close()
			channel = nil
		}
	}

		// MARK: - Subscription helpers

	public func sendTransactionStatusSubscribe(id: Flow.ID) async throws {
		let args = Flow.WebSocketTransactionStatusRequest(txId: id.hex)
		try await sendSubscribeMessage(
			subscriptionId: "tx:\(id.hex.prefix(16))",
			topic: .transactionStatuses,
			arguments: args
		)
	}

		// MARK: - Subscription frames

	public func sendSubscribeMessage<Arguments: Encodable & Sendable>(
		subscriptionId: String,
		topic: Flow.WebSocketTopic,
		arguments: Arguments
	) async throws {
		guard let channel = channel else {
			throw Flow.FError.customError(msg: "Cannot send subscribe message: WebSocket not connected")
		}

		let request = Flow.WebSocketSubscribeRequest(
			id: subscriptionId,
			action: .subscribe,
			topic: topic,
			arguments: arguments
		)

		let data = try JSONEncoder().encode(request)
		print("[FlowWS SEND] " + String(decoding: data, as: UTF8.self))
		var buffer = channel.allocator.buffer(capacity: data.count)
		buffer.writeBytes(data)

			// RFC 6455 §5.1: all client-to-server frames MUST be masked.
			// Sending maskKey: nil produced unmasked frames that Flow's access
			// node silently discarded server-side — the subscribe frame was
			// written successfully but never actually processed, so no
			// response ever arrived and every wait timed out.
		let maskKey = WebSocketMaskingKey((0..<4).map { _ in UInt8.random(in: 0...255) })
		let frame = WebSocketFrame(
			fin: true,
			rsv1: false,
			rsv2: false,
			rsv3: false,
			opcode: .text,
			maskKey: maskKey,
			data: buffer,
			extensionData: nil
		)

		try await channel.writeAndFlush(frame)
	}

		// MARK: - Internal connection helper

	private func connectWebSocket(to url: URL) async throws -> Channel {
		let scheme = url.scheme?.lowercased()
		let isTLS = (scheme == "wss")
		let host = url.host ?? "localhost"
		let port = url.port ?? (isTLS ? 443 : 80)

		let sslContext: NIOSSLContext?
		if isTLS {
			var tlsConfig = TLSConfiguration.makeClientConfiguration()
			tlsConfig.minimumTLSVersion = .tlsv12
			tlsConfig.certificateVerification = .fullVerification
				// The WebSocket upgrade handshake (HTTP Upgrade header) only exists
				// in HTTP/1.1 — HTTP/2 uses a different mechanism (RFC 8441) that
				// this NIO pipeline does not implement. Without pinning ALPN, this
				// server negotiates h2 by default and rejects the upgrade with a
				// 400 Bad Request, which surfaced as our connect/read timeouts.
			tlsConfig.applicationProtocols = ["http/1.1"]
			sslContext = try NIOSSLContext(configuration: tlsConfig)
		} else {
			sslContext = nil
		}

		let promise = group.next().makePromise(of: Channel.self)
		let deliver = self.onEnvelope  // capture before entering bootstrap closure

		let bootstrap = ClientBootstrap(group: group)
			.channelOption(ChannelOptions.autoRead, value: true)
			.channelInitializer { channel in
				if let context = sslContext {
					do {
						let sslHandler = try NIOSSLClientHandler(
							context: context,
							serverHostname: host
						)
						try channel.pipeline.syncOperations.addHandler(sslHandler)
					} catch {
						return channel.eventLoop.makeFailedFuture(error)
					}
				}

				return Self.addHTTPAndWebSocketHandlers(
					to: channel,
					onEnvelope: deliver,
					upgradePromise: promise
				)
			}

		bootstrap.connect(host: host, port: port).whenComplete { result in
			switch result {
				case .success(let channel):
					var headers = HTTPHeaders()
					headers.add(name: "Host", value: host)

						// Do NOT add Connection/Upgrade/Sec-WebSocket-* headers here.
						// NIOHTTPClientUpgradeHandler intercepts this request and calls
						// each upgrader's addCustom(upgradeRequestHeaders:) to inject
						// its own Sec-WebSocket-Key. Adding our own key here caused a
						// Sec-WebSocket-Accept mismatch during shouldAllowUpgrade,
						// silently failing the upgrade and hanging until timeout.

					var path = url.path
					if path.isEmpty { path = "/" }
					if let query = url.query, !query.isEmpty {
						path += "?" + query
					}

					let requestHead = HTTPRequestHead(
						version: .http1_1,
						method: .GET,
						uri: path,
						headers: headers
					)

					channel.write(HTTPClientRequestPart.head(requestHead), promise: nil)
					channel.writeAndFlush(HTTPClientRequestPart.end(nil), promise: nil)

						// Do NOT succeed the connect promise here — the HTTP request has
						// only been written, the WebSocket upgrade has not completed yet.
						// Resolving early lets callers treat a still-HTTP channel as a
						// ready WebSocket, which crashes when a WS frame is later written
						// onto a pipeline that still has the HTTP codec installed.
						// The promise is now completed by FlowWebSocketUpgradeEvent
						// handling below, once the upgrade genuinely finishes.

				case .failure(let error):
					promise.fail(error)
			}
		}

		return try await withThrowingTaskGroup(of: Channel.self) { group in
			group.addTask {
				try await promise.futureResult.get()
			}
			group.addTask {
				try await _Concurrency.Task.sleep(nanoseconds: 10_000_000_000)
				promise.fail(Flow.FError.customError(msg: "WebSocket connect timed out after 10s"))
				throw Flow.FError.customError(msg: "WebSocket connect timed out after 10s")
			}
			defer { group.cancelAll() }
			return try await group.next()!
		}
	}

	private static func addHTTPAndWebSocketHandlers(
		to channel: Channel,
		onEnvelope: (@Sendable (Flow.WebSocketEnvelope) -> Void)?,
		upgradePromise: EventLoopPromise<Channel>
	) -> EventLoopFuture<Void> {
		let websocketUpgrader = NIOWebSocketClientUpgrader(
			maxFrameSize: 1 << 24,
			automaticErrorHandling: true
		) { channel, _ in
			channel.pipeline.addHandler(FlowWebSocketFrameHandler(onEnvelope: onEnvelope))
		}

		let upgradeConfig: NIOHTTPClientUpgradeSendableConfiguration = (
			upgraders: [websocketUpgrader],
			completionHandler: { context in
				context.fireUserInboundEventTriggered(FlowWebSocketUpgradeEvent.upgraded)
				context.channel.read()
					// The upgrade has now genuinely completed and the HTTP codec has
					// been removed from the pipeline by addHTTPClientHandlers — only
					// now is it safe to hand the channel back to callers as a ready
					// WebSocket connection.
				upgradePromise.succeed(context.channel)
			}
		)

		return channel.pipeline.addHTTPClientHandlers(
			position: .last,
			leftOverBytesStrategy: .dropBytes,
			withClientUpgrade: upgradeConfig
		)
	}
}
