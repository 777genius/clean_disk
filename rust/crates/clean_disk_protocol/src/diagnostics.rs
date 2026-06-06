use crate::{DecimalUsizeDto, ProtocolVersionDto};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct DaemonDiagnosticsDto {
    protocol_version: ProtocolVersionDto,
    active_sessions: DecimalUsizeDto,
    running_sessions: DecimalUsizeDto,
    completed_sessions: DecimalUsizeDto,
    cancel_requested_sessions: DecimalUsizeDto,
    buffered_events: DecimalUsizeDto,
    stored_cursors: DecimalUsizeDto,
    auth_required: bool,
}

impl DaemonDiagnosticsDto {
    #[allow(clippy::too_many_arguments)]
    pub const fn new(
        protocol_version: ProtocolVersionDto,
        active_sessions: DecimalUsizeDto,
        running_sessions: DecimalUsizeDto,
        completed_sessions: DecimalUsizeDto,
        cancel_requested_sessions: DecimalUsizeDto,
        buffered_events: DecimalUsizeDto,
        stored_cursors: DecimalUsizeDto,
        auth_required: bool,
    ) -> Self {
        Self {
            protocol_version,
            active_sessions,
            running_sessions,
            completed_sessions,
            cancel_requested_sessions,
            buffered_events,
            stored_cursors,
            auth_required,
        }
    }

    pub const fn protocol_version(&self) -> ProtocolVersionDto {
        self.protocol_version
    }

    pub const fn active_sessions(&self) -> &DecimalUsizeDto {
        &self.active_sessions
    }

    pub const fn running_sessions(&self) -> &DecimalUsizeDto {
        &self.running_sessions
    }

    pub const fn completed_sessions(&self) -> &DecimalUsizeDto {
        &self.completed_sessions
    }

    pub const fn cancel_requested_sessions(&self) -> &DecimalUsizeDto {
        &self.cancel_requested_sessions
    }

    pub const fn buffered_events(&self) -> &DecimalUsizeDto {
        &self.buffered_events
    }

    pub const fn stored_cursors(&self) -> &DecimalUsizeDto {
        &self.stored_cursors
    }

    pub const fn auth_required(&self) -> bool {
        self.auth_required
    }
}
