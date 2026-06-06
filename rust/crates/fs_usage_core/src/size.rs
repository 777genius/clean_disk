#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
pub struct SizeBytes(u64);

impl SizeBytes {
    pub const ZERO: Self = Self(0);

    pub const fn new(bytes: u64) -> Self {
        Self(bytes)
    }

    pub const fn get(self) -> u64 {
        self.0
    }

    pub fn checked_add(self, other: Self) -> Option<Self> {
        self.0.checked_add(other.0).map(Self)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum MeasuredQuantity {
    ApparentBytes,
    AllocatedBytes,
    BlockCount,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum EvidenceConfidence {
    Exact,
    High,
    Medium,
    Low,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct SizeFact {
    raw_value: u64,
    quantity: MeasuredQuantity,
    byte_equivalent: Option<SizeBytes>,
    confidence: EvidenceConfidence,
}

impl SizeFact {
    pub const fn new(
        raw_value: u64,
        quantity: MeasuredQuantity,
        byte_equivalent: Option<SizeBytes>,
        confidence: EvidenceConfidence,
    ) -> Self {
        Self {
            raw_value,
            quantity,
            byte_equivalent,
            confidence,
        }
    }

    pub const fn raw_value(self) -> u64 {
        self.raw_value
    }

    pub const fn quantity(self) -> MeasuredQuantity {
        self.quantity
    }

    pub const fn byte_equivalent(self) -> Option<SizeBytes> {
        self.byte_equivalent
    }

    pub const fn confidence(self) -> EvidenceConfidence {
        self.confidence
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ReclaimEstimate {
    bytes: SizeBytes,
    confidence: EvidenceConfidence,
}

impl ReclaimEstimate {
    pub const fn new(bytes: SizeBytes, confidence: EvidenceConfidence) -> Self {
        Self { bytes, confidence }
    }

    pub const fn bytes(self) -> SizeBytes {
        self.bytes
    }

    pub const fn confidence(self) -> EvidenceConfidence {
        self.confidence
    }
}
