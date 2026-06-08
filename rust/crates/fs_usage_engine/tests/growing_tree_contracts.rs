use fs_usage_core::{
    ChildCompleteness, EvidenceConfidence, MeasuredQuantity, NodeKind, PartialNodeId,
    ScanSessionId, SizeBytes, SizeFact,
};
use fs_usage_engine::{
    GrowingNodeState, GrowingTreeBatch, GrowingTreeBatchError, GrowingTreeEvent, PartialNodeName,
};

fn session_id(value: u128) -> ScanSessionId {
    ScanSessionId::new(value).expect("session id")
}

fn partial_node_id(value: u64) -> PartialNodeId {
    PartialNodeId::new(value).expect("partial node id")
}

fn size(bytes: u64) -> SizeFact {
    SizeFact::new(
        bytes,
        MeasuredQuantity::ApparentBytes,
        Some(SizeBytes::new(bytes)),
        EvidenceConfidence::Low,
    )
}

#[test]
fn partial_node_names_reject_empty_values() {
    assert_eq!(
        PartialNodeName::new("  ").expect_err("empty name"),
        fs_usage_engine::PartialNodeNameError::Empty
    );
    assert_eq!(
        PartialNodeName::new("Caches").expect("node name").as_str(),
        "Caches"
    );
}

#[test]
fn growing_tree_batch_requires_events_from_one_session() {
    let first_session = session_id(10);
    let second_session = session_id(11);
    let event = GrowingTreeEvent::NodeDiscovered {
        session_id: first_session,
        node_id: partial_node_id(1),
        parent_id: None,
        name: PartialNodeName::new("Library").expect("name"),
        kind: NodeKind::Directory,
    };

    let batch = GrowingTreeBatch::new(first_session, 1, vec![event.clone()]).expect("batch");
    assert_eq!(batch.session_id(), first_session);
    assert_eq!(batch.scanned_items(), 1);
    assert_eq!(batch.events(), &[event]);

    let mismatch = GrowingTreeBatch::new(second_session, 1, batch.events().to_vec())
        .expect_err("session mismatch");
    assert_eq!(mismatch, GrowingTreeBatchError::SessionMismatch);
}

#[test]
fn growing_tree_events_are_never_cleanup_authority() {
    let session = session_id(12);
    let node = partial_node_id(1);
    let events = vec![
        GrowingTreeEvent::NodeSizeUpdated {
            session_id: session,
            node_id: node,
            aggregate_size: size(1024),
            state: GrowingNodeState::Scanning,
        },
        GrowingTreeEvent::NodeCompleted {
            session_id: session,
            node_id: node,
            aggregate_size: size(2048),
            child_completeness: ChildCompleteness::Complete,
        },
    ];

    for event in events {
        assert!(!event.is_cleanup_authority());
    }
    assert!(!GrowingNodeState::Complete.is_cleanup_authority());
}

#[test]
fn growing_tree_batch_rejects_empty_event_list() {
    let err = GrowingTreeBatch::new(session_id(13), 0, Vec::new()).expect_err("empty batch");
    assert_eq!(err, GrowingTreeBatchError::Empty);
}
