use fs_usage_core::{
    BoundaryPolicy, EvidenceConfidence, HardlinkPolicy, MeasuredQuantity, NodeId, ReclaimEstimate,
    ScanSessionId, ScanTarget, SizeBytes, SizeFact, TargetPath, TargetScope,
};

#[test]
fn ids_reject_zero_values() {
    assert!(ScanSessionId::new(0).is_none());
    assert!(NodeId::new(0).is_none());
    assert_eq!(ScanSessionId::new(7).expect("id").get(), 7);
    assert_eq!(NodeId::new(3).expect("node").get(), 3);
}

#[test]
fn measured_size_and_reclaim_estimate_are_separate_facts() {
    let measured = SizeFact::new(
        42,
        MeasuredQuantity::BlockCount,
        None,
        EvidenceConfidence::High,
    );
    let reclaim = ReclaimEstimate::new(SizeBytes::new(4096), EvidenceConfidence::Low);

    assert_eq!(measured.quantity(), MeasuredQuantity::BlockCount);
    assert_eq!(measured.byte_equivalent(), None);
    assert_eq!(reclaim.bytes().get(), 4096);
    assert_eq!(reclaim.confidence(), EvidenceConfidence::Low);
}

#[test]
fn scan_target_requires_non_empty_path() {
    assert!(TargetPath::new("   ").is_err());

    let target = ScanTarget::new(
        TargetPath::new("/tmp").expect("target path"),
        TargetScope::LocalPath,
        BoundaryPolicy::StayOnInitialFilesystem,
        HardlinkPolicy::Detect,
    );

    assert_eq!(target.path().as_str(), "/tmp");
    assert_eq!(target.scope(), TargetScope::LocalPath);
}
