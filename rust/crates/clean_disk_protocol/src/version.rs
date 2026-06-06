use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ProtocolVersionDto {
    major: u16,
    minor: u16,
}

impl ProtocolVersionDto {
    pub const CURRENT: Self = PROTOCOL_VERSION;

    pub const fn new(major: u16, minor: u16) -> Self {
        Self { major, minor }
    }

    pub const fn major(self) -> u16 {
        self.major
    }

    pub const fn minor(self) -> u16 {
        self.minor
    }

    pub const fn is_compatible_with(self, other: Self) -> bool {
        self.major == other.major && self.minor >= other.minor
    }
}

pub const PROTOCOL_VERSION: ProtocolVersionDto = ProtocolVersionDto::new(0, 5);

pub type ProtocolVersion = ProtocolVersionDto;
