use axum::{
    extract::{Extension, Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use std::sync::Arc;
use crate::AppState;
use crate::models::user::{Admin, CreateAdminRequest, UpdateAdminRequest};
use crate::handlers::auth::Claims;
use crate::utils::log_admin_action;
use crate::services::steam_api::SteamService;
use bcrypt::{hash, DEFAULT_COST};
use serde::{Deserialize, Serialize};
#[derive(Deserialize)]
pub struct PaginationQuery {
    pub page: Option<u64>,
    pub page_size: Option<u64>,
}

#[derive(Serialize)]
pub struct PaginatedResponse<T> {
    pub items: Vec<T>,
    pub total: i64,
    pub page: u64,
    pub page_size: u64,
}

fn normalize_pagination(params: &PaginationQuery) -> (u64, u64, i64) {
    let page = params.page.unwrap_or(1).max(1);
    let page_size = params.page_size.unwrap_or(20).clamp(1, 100);
    let offset = ((page - 1) * page_size) as i64;
    (page, page_size, offset)
}

#[utoipa::path(
    get,
    path = "/api/admins",
    responses(
        (status = 200, description = "List all admins", body = Vec<Admin>)
    ),
    security(
        ("jwt" = [])
    )
)]
pub async fn list_admins(
    State(state): State<Arc<AppState>>,
    Query(params): Query<PaginationQuery>,
) -> impl IntoResponse {
    let (page, page_size, offset) = normalize_pagination(&params);

    let total_result = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM admins")
        .fetch_one(&state.db)
        .await;

    let items_result = sqlx::query_as::<_, Admin>("SELECT * FROM admins ORDER BY created_at DESC LIMIT ? OFFSET ?")
        .bind(page_size as i64)
        .bind(offset)
        .fetch_all(&state.db)
        .await;

    match (total_result, items_result) {
        (Ok(total), Ok(items)) => (StatusCode::OK, Json(PaginatedResponse { items, total, page, page_size })).into_response(),
        (Err(e), _) | (_, Err(e)) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/api/admins",
    request_body = CreateAdminRequest,
    responses(
        (status = 201, description = "Admin created"),
        (status = 400, description = "Bad request")
    ),
    security(
        ("jwt" = [])
    )
)]
pub async fn create_admin(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<Claims>,
    Json(payload): Json<CreateAdminRequest>,
) -> impl IntoResponse {
    let hashed = hash(payload.password, DEFAULT_COST).unwrap();

    // 解析 SteamID 为各种格式
    let (steam_id_2, steam_id_3, steam_id_64) = if let Some(ref input_steam_id) = payload.steam_id {
        let steam_service = SteamService::new();
        let id64 = steam_service.resolve_steam_id(input_steam_id).await
            .unwrap_or_else(|| input_steam_id.clone());
        
        let id2 = steam_service.id64_to_id2(&id64);
        let id3 = steam_service.id64_to_id3(&id64);
        
        (id2, id3, Some(id64))
    } else {
        (None, None, None)
    };

    let result = sqlx::query(
        "INSERT INTO admins (username, password, role, steam_id, steam_id_3, steam_id_64, remark) VALUES (?, ?, ?, ?, ?, ?, ?)"
    )
    .bind(&payload.username)
    .bind(hashed)
    .bind(&payload.role)
    .bind(&steam_id_2)
    .bind(&steam_id_3)
    .bind(&steam_id_64)
    .bind(&payload.remark)
    .execute(&state.db)
    .await;

    match result {
        Ok(_) => {
            let _ = log_admin_action(
                &state.db,
                &user.sub,
                "create_admin",
                &payload.username,
                &format!("Role: {}", payload.role)
            ).await;
            (StatusCode::CREATED, Json("Admin created")).into_response()
        },
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}

#[utoipa::path(
    put,
    path = "/api/admins/{id}",
    params(
        ("id" = i64, Path, description = "Admin ID")
    ),
    request_body = UpdateAdminRequest,
    responses(
        (status = 200, description = "Admin updated"),
        (status = 404, description = "Admin not found")
    ),
    security(
        ("jwt" = [])
    )
)]
pub async fn update_admin(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<Claims>,
    Path(id): Path<i64>,
    Json(payload): Json<UpdateAdminRequest>,
) -> impl IntoResponse {
    if let Some(username) = payload.username {
        let _ = sqlx::query("UPDATE admins SET username = ? WHERE id = ?")
            .bind(username).bind(id)
            .execute(&state.db).await;
    }
    if let Some(password) = payload.password {
         let hashed = hash(password, DEFAULT_COST).unwrap();
         let _ = sqlx::query("UPDATE admins SET password = ? WHERE id = ?")
            .bind(hashed).bind(id)
            .execute(&state.db).await;
    }
    if let Some(role) = payload.role {
        let _ = sqlx::query("UPDATE admins SET role = ? WHERE id = ?")
            .bind(role).bind(id)
            .execute(&state.db).await;
    }
    if let Some(ref input_steam_id) = payload.steam_id {
        // 同时更新所有 SteamID 格式
        let steam_service = SteamService::new();
        let id64 = steam_service.resolve_steam_id(input_steam_id).await
            .unwrap_or_else(|| input_steam_id.clone());
        
        let id2 = steam_service.id64_to_id2(&id64);
        let id3 = steam_service.id64_to_id3(&id64);
        
        let _ = sqlx::query("UPDATE admins SET steam_id = ?, steam_id_3 = ?, steam_id_64 = ? WHERE id = ?")
            .bind(&id2)
            .bind(&id3)
            .bind(&id64)
            .bind(id)
            .execute(&state.db).await;
    }

    if let Some(remark) = payload.remark {
        let _ = sqlx::query("UPDATE admins SET remark = ? WHERE id = ?")
            .bind(remark).bind(id)
            .execute(&state.db).await;
    }

    let _ = log_admin_action(
        &state.db,
        &user.sub,
        "update_admin",
        &format!("AdminID: {}", id),
        "Updated admin details"
    ).await;

    (StatusCode::OK, Json("Admin updated")).into_response()
}

#[utoipa::path(
    delete,
    path = "/api/admins/{id}",
    params(
        ("id" = i64, Path, description = "Admin ID")
    ),
    responses(
        (status = 200, description = "Admin deleted"),
        (status = 404, description = "Admin not found")
    ),
    security(
        ("jwt" = [])
    )
)]
pub async fn delete_admin(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<Claims>,
    Path(id): Path<i64>,
) -> impl IntoResponse {
    let result = sqlx::query("DELETE FROM admins WHERE id = ?")
        .bind(id)
        .execute(&state.db)
        .await;

    match result {
        Ok(_) => {
             let _ = log_admin_action(
                &state.db,
                &user.sub,
                "delete_admin",
                &format!("AdminID: {}", id),
                "Deleted admin"
            ).await;
            (StatusCode::OK, Json("Admin deleted")).into_response()
        },
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    }
}
