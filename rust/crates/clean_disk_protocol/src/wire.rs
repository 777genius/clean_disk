use schemars::JsonSchema;
use serde::{Deserialize, Deserializer, Serialize, Serializer, de};
use std::{fmt, str::FromStr};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SensitiveTextError {
    Empty,
}

macro_rules! decimal_wire_type {
    ($name:ident, $primitive:ty, $constructor:ident, $accessor:ident) => {
        #[derive(Clone, PartialEq, Eq, Hash, JsonSchema)]
        #[schemars(transparent)]
        pub struct $name(String);

        impl $name {
            pub fn $constructor(value: $primitive) -> Self {
                Self(value.to_string())
            }

            pub fn $accessor(&self) -> $primitive {
                self.0
                    .parse::<$primitive>()
                    .expect("decimal wire value is validated on construction and deserialization")
            }

            pub fn as_str(&self) -> &str {
                &self.0
            }
        }

        impl fmt::Debug for $name {
            fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
                formatter
                    .debug_tuple(stringify!($name))
                    .field(&self.0)
                    .finish()
            }
        }

        impl Serialize for $name {
            fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
            where
                S: Serializer,
            {
                serializer.serialize_str(&self.0)
            }
        }

        impl<'de> Deserialize<'de> for $name {
            fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
            where
                D: Deserializer<'de>,
            {
                let value = String::deserialize(deserializer)?;
                validate_decimal::<$primitive, D::Error>(&value)?;
                Ok(Self(value))
            }
        }
    };
}

decimal_wire_type!(DecimalU64Dto, u64, from_u64, to_u64);
decimal_wire_type!(DecimalU128Dto, u128, from_u128, to_u128);
decimal_wire_type!(DecimalUsizeDto, usize, from_usize, to_usize);

#[derive(Clone, PartialEq, Eq, Hash, Serialize, JsonSchema)]
#[schemars(transparent)]
#[serde(transparent)]
pub struct OpaqueCursorDto(String);

impl OpaqueCursorDto {
    pub fn new(value: impl Into<String>) -> Result<Self, SensitiveTextError> {
        non_empty(value.into()).map(Self)
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Debug for OpaqueCursorDto {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("OpaqueCursorDto(<opaque>)")
    }
}

impl<'de> Deserialize<'de> for OpaqueCursorDto {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        non_empty(value).map(Self).map_err(de::Error::custom)
    }
}

#[derive(Clone, PartialEq, Eq, Hash, Serialize, JsonSchema)]
#[schemars(transparent)]
#[serde(transparent)]
pub struct RawPathDto(String);

impl RawPathDto {
    pub fn new(value: impl Into<String>) -> Result<Self, SensitiveTextError> {
        non_empty(value.into()).map(Self)
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Debug for RawPathDto {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("RawPathDto(<redacted>)")
    }
}

impl<'de> Deserialize<'de> for RawPathDto {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        non_empty(value).map(Self).map_err(de::Error::custom)
    }
}

#[derive(Clone, PartialEq, Eq, Hash, Serialize, JsonSchema)]
#[schemars(transparent)]
#[serde(transparent)]
pub struct SearchTextDto(String);

impl SearchTextDto {
    pub fn new(value: impl Into<String>) -> Result<Self, SensitiveTextError> {
        non_empty(value.into()).map(Self)
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Debug for SearchTextDto {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("SearchTextDto(<redacted>)")
    }
}

impl<'de> Deserialize<'de> for SearchTextDto {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        non_empty(value).map(Self).map_err(de::Error::custom)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum PathPrivacyDto {
    Raw,
    Redacted,
    Unavailable,
    #[serde(other)]
    Unknown,
}

#[derive(Clone, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct DisplayPathDto {
    text: String,
    privacy: PathPrivacyDto,
}

impl DisplayPathDto {
    pub fn new(text: impl Into<String>, privacy: PathPrivacyDto) -> Self {
        Self {
            text: text.into(),
            privacy,
        }
    }

    pub fn text(&self) -> &str {
        &self.text
    }

    pub const fn privacy(&self) -> PathPrivacyDto {
        self.privacy
    }
}

impl fmt::Debug for DisplayPathDto {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("DisplayPathDto")
            .field("text", &"<redacted>")
            .field("privacy", &self.privacy)
            .finish()
    }
}

fn non_empty(value: String) -> Result<String, SensitiveTextError> {
    if value.trim().is_empty() {
        Err(SensitiveTextError::Empty)
    } else {
        Ok(value)
    }
}

fn validate_decimal<T, E>(value: &str) -> Result<(), E>
where
    T: FromStr,
    E: de::Error,
{
    if value.is_empty() || !value.bytes().all(|byte| byte.is_ascii_digit()) {
        return Err(E::custom("expected a non-empty decimal string"));
    }
    value
        .parse::<T>()
        .map(|_| ())
        .map_err(|_| E::custom("decimal string is outside supported range"))
}

impl fmt::Display for SensitiveTextError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Empty => formatter.write_str("value must not be empty"),
        }
    }
}

impl std::error::Error for SensitiveTextError {}
