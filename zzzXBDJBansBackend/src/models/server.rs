use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use chrono::{DateTime, Utc};
use utoipa::ToSchema;

#[derive(Debug, Serialize, Deserialize, FromRow, ToSchema)]
pub struct ServerGroup {
    pub id: i64,
    pub name: String,
    pub created_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, Deserialize, FromRow, ToSchema)]
pub struct Server {
    pub id: i64,
    pub group_id: i64,
    pub name: String,
    pub ip: String,
    pub port: i32,
    pub rcon_password: Option<String>,
    pub created_at: Option<DateTime<Utc>>,
    #[sqlx(default)]
    pub verification_enabled: bool,
    #[sqlx(default)]
    pub enable_whitelist: bool,
    #[sqlx(default)]
    pub min_rating: f32,
    #[sqlx(default)]
    pub min_steam_level: i32,
}

// Responses often group servers by group
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct GroupWithServers {
    pub id: i64,
    pub name: String,
    pub servers: Vec<Server>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct CreateGroupRequest {
    pub name: String,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct CreateServerRequest {
    pub group_id: i64,
    pub name: String,
    pub ip: String,
    pub port: i32,
    pub rcon_password: Option<String>,
    pub verification_enabled: Option<bool>,
    pub enable_whitelist: Option<bool>,
    pub min_rating: Option<f32>,
    pub min_steam_level: Option<i32>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct UpdateServerRequest {
    pub name: Option<String>,
    pub ip: Option<String>,
    pub port: Option<i32>,
    pub rcon_password: Option<String>,
    pub verification_enabled: Option<bool>,
    pub enable_whitelist: Option<bool>,
    pub min_rating: Option<f32>,
    pub min_steam_level: Option<i32>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct CheckServerRequest {
    pub ip: String,
    pub port: u16,
    pub rcon_password: Option<String>,
}
