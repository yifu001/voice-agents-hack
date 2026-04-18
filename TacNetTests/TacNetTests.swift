import XCTest
@testable import TacNet

final class TacNetTests: XCTestCase {
    func testCactusFunctionsAreCallableViaSwiftBindings() {
        XCTAssertTrue(CactusFunctionProbe.verifyCallableSymbols())
    }

    func testFrameworkImportsProbeCompiles() {
        FrameworkImportsProbe.touchFrameworkSymbols()
        XCTAssertTrue(true)
    }

    func testTreeNodeRoundTripEncodingWithNestedChildren() throws {
        let original = TreeNode(
            id: "root",
            label: "Root",
            claimedBy: "commander",
            children: [
                TreeNode(
                    id: "alpha",
                    label: "Alpha",
                    claimedBy: nil,
                    children: [
                        TreeNode(
                            id: "alpha-1",
                            label: "Alpha 1",
                            claimedBy: "device-a1",
                            children: []
                        )
                    ]
                ),
                TreeNode(
                    id: "bravo",
                    label: "Bravo",
                    claimedBy: "device-b",
                    children: []
                )
            ]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TreeNode.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testTreeNodeDecodingRejectsMalformedJSON() {
        let malformedPayloads = [
            #"{"label":"Root","claimed_by":null,"children":[]}"#, // missing id
            #"{"id":"root","label":"Root","claimed_by":null,"children":"invalid"}"#, // children wrong type
            #"{}"#, // empty object
            #"[]"#  // array instead of object
        ]

        for json in malformedPayloads {
            let data = Data(json.utf8)
            XCTAssertThrowsError(try JSONDecoder().decode(TreeNode.self, from: data)) { error in
                XCTAssertTrue(error is DecodingError, "Expected DecodingError, got \(type(of: error))")
            }
        }
    }

    func testNetworkConfigVersionMonotonicityAndStaleDiscard() {
        let networkID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        var local = NetworkConfig(
            networkName: "TacNet Alpha",
            networkID: networkID,
            createdBy: "organizer-device",
            pinHash: "pinhash",
            version: 1,
            tree: TreeNode(id: "root", label: "Root", claimedBy: nil, children: [])
        )

        local.applyMutation { tree in
            tree.label = "Root Updated"
        }
        XCTAssertEqual(local.version, 2, "Tree mutation must increment version exactly by 1")

        let stale = NetworkConfig(
            networkName: "TacNet Alpha",
            networkID: networkID,
            createdBy: "organizer-device",
            pinHash: "pinhash",
            version: 2,
            tree: TreeNode(id: "root", label: "STALE", claimedBy: nil, children: [])
        )
        XCTAssertFalse(local.mergeIfNewer(stale), "Stale versions (<= local) must be discarded")
        XCTAssertEqual(local.tree.label, "Root Updated")

        let jumped = NetworkConfig(
            networkName: "TacNet Alpha",
            networkID: networkID,
            createdBy: "organizer-device",
            pinHash: "pinhash",
            version: 5,
            tree: TreeNode(id: "root", label: "Fresh", claimedBy: nil, children: [])
        )
        XCTAssertTrue(local.mergeIfNewer(jumped), "Higher versions must be accepted even if > local + 1")
        XCTAssertEqual(local.version, 5)
        XCTAssertEqual(local.tree.label, "Fresh")
    }

    func testMessageEnvelopeSerializationHasAllRequiredFields() throws {
        let message = Message.make(
            type: .broadcast,
            senderID: "device-alpha",
            senderRole: "leaf",
            parentID: "parent-1",
            treeLevel: 2,
            ttl: 4,
            encrypted: false,
            latitude: 37.3318,
            longitude: -122.0312,
            accuracy: 5.0,
            transcript: "CONTACT front",
            summary: nil,
            claimedNodeID: nil,
            targetNodeID: nil,
            rejectionReason: nil,
            tree: nil,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoded = try JSONEncoder().encode(message)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        let id = try XCTUnwrap(json["id"] as? String)
        XCTAssertNotNil(UUID(uuidString: id), "id should encode as UUID string")

        XCTAssertTrue(json["type"] is String, "type should serialize as a string")
        XCTAssertTrue(json["sender_id"] is String)
        XCTAssertTrue(json["sender_role"] is String)
        XCTAssertTrue(json["parent_id"] is String)
        XCTAssertTrue(json["tree_level"] is NSNumber)
        XCTAssertTrue(json["timestamp"] is NSNumber || json["timestamp"] is String)
        XCTAssertTrue(json["ttl"] is NSNumber)

        let payload = try XCTUnwrap(json["payload"] as? [String: Any])
        XCTAssertTrue(payload["encrypted"] is Bool || payload["encrypted"] is NSNumber)
        XCTAssertTrue(payload["transcript"] is String)
        XCTAssertTrue(payload["location"] is [String: Any], "location must be present in payload")
    }

    func testMessageTypeEnumCoverageAndUnknownTypeRejection() throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        try Message.MessageType.allCases.forEach { messageType in
            let original = Message.make(
                type: messageType,
                senderID: "device-1",
                senderRole: "participant",
                parentID: "root",
                treeLevel: 1,
                ttl: 3,
                encrypted: true,
                latitude: 1.0,
                longitude: 2.0,
                accuracy: 3.0,
                transcript: "sample",
                summary: "sample-summary",
                claimedNodeID: "node-1",
                targetNodeID: "node-2",
                rejectionReason: "organiser_wins",
                tree: TreeNode(id: "root", label: "Root", claimedBy: nil, children: []),
                timestamp: Date(timeIntervalSince1970: 1_700_000_001)
            )

            let roundTripped = try decoder.decode(Message.self, from: encoder.encode(original))
            XCTAssertEqual(roundTripped.type, messageType)
        }

        let unknownTypeJSON = """
        {
          "id":"11111111-2222-3333-4444-555555555555",
          "type":"UNKNOWN_TYPE",
          "sender_id":"device-1",
          "sender_role":"participant",
          "parent_id":"root",
          "tree_level":1,
          "timestamp":1700000001,
          "ttl":3,
          "payload":{
            "location":{"lat":0,"lon":0,"accuracy":-1,"is_fallback":true},
            "encrypted":false
          }
        }
        """

        XCTAssertThrowsError(try decoder.decode(Message.self, from: Data(unknownTypeJSON.utf8))) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testNodeIdentityPersistsAcrossSimulatedRestartAndCanBeCleared() throws {
        let suiteName = "TacNetTests.NodeIdentity.\(UUID().uuidString)"
        let defaultsA = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaultsA.removePersistentDomain(forName: suiteName)
        defer { defaultsA.removePersistentDomain(forName: suiteName) }

        let storeA = NodeIdentityStore(defaults: defaultsA)
        let identity = NodeIdentity(
            deviceID: "device-xyz",
            claimedNodeID: "node-007",
            networkID: UUID(uuidString: "AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB")!
        )

        XCTAssertNoThrow(try storeA.save(identity))

        let defaultsB = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let storeB = NodeIdentityStore(defaults: defaultsB)
        XCTAssertEqual(storeB.load(), identity, "Identity should survive simulated relaunch")

        storeB.clear()
        XCTAssertNil(storeA.load(), "Cleared identity should be nil on next read")
    }

    func testGPSCoordinateEmbeddingUsesLiveValuesAndFallbackWhenUnavailable() throws {
        let withLocation = Message.make(
            type: .broadcast,
            senderID: "device-live",
            senderRole: "leaf",
            parentID: "parent-2",
            treeLevel: 2,
            ttl: 5,
            encrypted: false,
            latitude: 34.0522,
            longitude: -118.2437,
            accuracy: 4.5,
            transcript: "Movement east",
            summary: nil,
            claimedNodeID: nil,
            targetNodeID: nil,
            rejectionReason: nil,
            tree: nil
        )

        XCTAssertEqual(withLocation.payload.location.lat, 34.0522, accuracy: 0.000001)
        XCTAssertEqual(withLocation.payload.location.lon, -118.2437, accuracy: 0.000001)
        XCTAssertEqual(withLocation.payload.location.accuracy, 4.5, accuracy: 0.000001)
        XCTAssertFalse(withLocation.payload.location.isFallback)

        let withoutLocation = Message.make(
            type: .broadcast,
            senderID: "device-fallback",
            senderRole: "leaf",
            parentID: "parent-2",
            treeLevel: 2,
            ttl: 5,
            encrypted: false,
            latitude: nil,
            longitude: nil,
            accuracy: nil,
            transcript: "Fallback position",
            summary: nil,
            claimedNodeID: nil,
            targetNodeID: nil,
            rejectionReason: nil,
            tree: nil
        )

        XCTAssertTrue(withoutLocation.payload.location.isFallback, "Fallback GPS should be flagged")

        let encoded = try JSONEncoder().encode(withoutLocation)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let payload = try XCTUnwrap(json["payload"] as? [String: Any])
        XCTAssertNotNil(payload["location"], "location field must be present even without live GPS")
    }

    func testTreeHelpersParentLookupForRootLeafIntermediateAndMissing() {
        let tree = makeFixtureTree()

        XCTAssertEqual(TreeHelpers.parent(of: "alpha", in: tree)?.id, "root")
        XCTAssertEqual(TreeHelpers.parent(of: "alpha-1", in: tree)?.id, "alpha")
        XCTAssertNil(TreeHelpers.parent(of: "root", in: tree))
        XCTAssertNil(TreeHelpers.parent(of: "missing", in: tree))
    }

    func testTreeHelpersSiblingsLookupExcludesSelfAndHandlesRootSingleChildAndMissing() {
        let tree = makeFixtureTree()

        XCTAssertEqual(TreeHelpers.siblings(of: "alpha-1", in: tree).map(\.id), ["alpha-2"])
        XCTAssertEqual(TreeHelpers.siblings(of: "alpha", in: tree).map(\.id), ["bravo", "charlie"])
        XCTAssertEqual(TreeHelpers.siblings(of: "charlie-1", in: tree).count, 0, "Single child should have no siblings")
        XCTAssertEqual(TreeHelpers.siblings(of: "root", in: tree).count, 0, "Root should have no siblings")
        XCTAssertEqual(TreeHelpers.siblings(of: "missing", in: tree).count, 0, "Missing node should produce no siblings")
    }

    func testTreeHelpersChildrenLookupForRootIntermediateLeafAndMissing() {
        let tree = makeFixtureTree()

        XCTAssertEqual(TreeHelpers.children(of: "root", in: tree).map(\.id), ["alpha", "bravo", "charlie"])
        XCTAssertEqual(TreeHelpers.children(of: "alpha", in: tree).map(\.id), ["alpha-1", "alpha-2"])
        XCTAssertEqual(TreeHelpers.children(of: "bravo", in: tree).count, 0, "Leaf should have no children")
        XCTAssertEqual(TreeHelpers.children(of: "missing", in: tree).count, 0, "Missing node should produce no children")
    }

    func testTreeHelpersLevelLookupForRootIntermediateLeafAndMissing() {
        let tree = makeFixtureTree()

        XCTAssertEqual(TreeHelpers.level(of: "root", in: tree), 0)
        XCTAssertEqual(TreeHelpers.level(of: "alpha", in: tree), 1)
        XCTAssertEqual(TreeHelpers.level(of: "alpha-1", in: tree), 2)
        XCTAssertNil(TreeHelpers.level(of: "missing", in: tree))
    }

    func testMessageDeduplicatorReturnsFalseForFirstSeenAndTrueForReseen() {
        let deduplicator = MessageDeduplicator(capacity: 50_000)
        let id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

        XCTAssertFalse(deduplicator.isDuplicate(messageId: id))
        XCTAssertTrue(deduplicator.isDuplicate(messageId: id))
    }

    func testMessageDeduplicatorDifferentUUIDsAreNotDuplicates() {
        let deduplicator = MessageDeduplicator(capacity: 50_000)
        let idA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let idB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

        XCTAssertFalse(deduplicator.isDuplicate(messageId: idA))
        XCTAssertFalse(deduplicator.isDuplicate(messageId: idB))
    }

    func testMessageDeduplicatorStress10kEntriesMaintainsCorrectness() {
        let deduplicator = MessageDeduplicator(capacity: 50_000)
        let ids = (0..<10_000).map(deterministicUUID(from:))

        ids.forEach { id in
            XCTAssertFalse(deduplicator.isDuplicate(messageId: id), "First-seen UUID must not be duplicate")
        }

        ids.forEach { id in
            XCTAssertTrue(deduplicator.isDuplicate(messageId: id), "Re-seen UUID must be duplicate")
        }
    }

    func testMessageDeduplicatorBoundedGrowthAndRecentEntriesRemainTracked() {
        let capacity = 1_000
        let deduplicator = MessageDeduplicator(capacity: capacity)
        let ids = (0..<(capacity * 2)).map(deterministicUUID(from:))

        ids.forEach { id in
            XCTAssertFalse(deduplicator.isDuplicate(messageId: id))
        }

        XCTAssertEqual(deduplicator.trackedCount, capacity, "Seen-set size should remain bounded by capacity")

        ids.suffix(1_000).forEach { id in
            XCTAssertTrue(deduplicator.isDuplicate(messageId: id), "Most-recent IDs should still be tracked")
        }

        XCTAssertFalse(deduplicator.isDuplicate(messageId: ids[0]), "Oldest entries should be evicted after overflow")
    }

    private func makeFixtureTree() -> TreeNode {
        TreeNode(
            id: "root",
            label: "Root",
            claimedBy: nil,
            children: [
                TreeNode(
                    id: "alpha",
                    label: "Alpha",
                    claimedBy: nil,
                    children: [
                        TreeNode(id: "alpha-1", label: "Alpha 1", claimedBy: nil, children: []),
                        TreeNode(id: "alpha-2", label: "Alpha 2", claimedBy: nil, children: [])
                    ]
                ),
                TreeNode(
                    id: "bravo",
                    label: "Bravo",
                    claimedBy: nil,
                    children: []
                ),
                TreeNode(
                    id: "charlie",
                    label: "Charlie",
                    claimedBy: nil,
                    children: [
                        TreeNode(id: "charlie-1", label: "Charlie 1", claimedBy: nil, children: [])
                    ]
                )
            ]
        )
    }

    private func deterministicUUID(from value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", value))!
    }
}
