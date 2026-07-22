//
//  ARMultipeerSession.swift
//  AniMagic
//
//  Created by Amelia Putri Aftiana on 22/07/26.
//

import Foundation
import MultipeerConnectivity
import UIKit

enum ARMultiplayerStatus: Equatable {
    case disabled
    case searching
    case connected(Int)
    case synchronizing
    case ready(Int)
    case failed(String)

    var title: String {
        switch self {
        case .disabled: "Solo world"
        case .searching: "Looking for players…"
        case .connected(let count): "Player connected \(count)"
        case .synchronizing: "Syncing magic worlds…"
        case .ready(let count): "Playing together \(count)"
        case .failed(let message): message
        }
    }

    var icon: String {
        switch self {
        case .disabled: "person"
        case .searching: "person.2"
        case .connected, .synchronizing, .ready: "person.2.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}

final class ARMultipeerSession: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    private enum PacketKind: UInt8 {
        case collaboration = 1
        case sharedObject = 2
    }

    static let serviceType = "animagic-ar"

    var onStatusChanged: ((ARMultiplayerStatus) -> Void)?
    var onCollaborationDataReceived: ((Data) -> Void)?
    var onSharedObjectReceived: ((ARSharedObjectPayload) -> Void)?
    var onPeerConnected: (() -> Void)?

    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession?
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?
    private(set) var isRunning = false

    var connectedPeerCount: Int {
        session?.connectedPeers.count ?? 0
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        serviceAdvertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        serviceBrowser = browser

        notifyStatus(.searching)
    }

    func stop() {
        guard isRunning else {
            notifyStatus(.disabled)
            return
        }
        isRunning = false
        serviceAdvertiser?.stopAdvertisingPeer()
        serviceBrowser?.stopBrowsingForPeers()
        session?.disconnect()
        serviceAdvertiser = nil
        serviceBrowser = nil
        session = nil
        notifyStatus(.disabled)
    }

    func sendCollaborationData(_ data: Data, reliably: Bool) {
        send(packetKind: .collaboration, payload: data, reliably: reliably)
    }

    func sendSharedObject(_ object: ARSharedObjectPayload) {
        guard let data = try? JSONEncoder().encode(object) else { return }
        send(packetKind: .sharedObject, payload: data, reliably: true)
    }

    private func send(packetKind: PacketKind, payload: Data, reliably: Bool) {
        guard isRunning,
              let session,
              !session.connectedPeers.isEmpty else {
            return
        }

        var packet = Data([packetKind.rawValue])
        packet.append(payload)
        do {
            try session.send(
                packet,
                toPeers: session.connectedPeers,
                with: reliably ? .reliable : .unreliable
            )
        } catch {
            notifyStatus(.failed("Couldn’t share the magic world."))
        }
    }

    private func notifyStatus(_ status: ARMultiplayerStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatusChanged?(status)
        }
    }

    private func handleReceivedData(_ data: Data) {
        guard let kind = data.first,
              let packetKind = PacketKind(rawValue: kind) else {
            return
        }
        let payload = Data(data.dropFirst())
        switch packetKind {
        case .collaboration:
            onCollaborationDataReceived?(payload)
        case .sharedObject:
            guard let object = try? JSONDecoder().decode(ARSharedObjectPayload.self, from: payload) else {
                return
            }
            onSharedObjectReceived?(object)
        }
    }

    // MARK: - MCSessionDelegate

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                self.notifyStatus(.connected(session.connectedPeers.count))
                self.onPeerConnected?()
            case .connecting:
                self.notifyStatus(.searching)
            case .notConnected:
                if self.isRunning {
                    self.notifyStatus(session.connectedPeers.isEmpty ? .searching : .connected(session.connectedPeers.count))
                }
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.handleReceivedData(data)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}

    // MARK: - Discovery delegates

    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        guard let session, !session.connectedPeers.contains(peerID) else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(true, session)
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        notifyStatus(.failed("Nearby multiplayer isn’t available."))
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
        notifyStatus(.failed("Nearby multiplayer isn’t available."))
    }
}
