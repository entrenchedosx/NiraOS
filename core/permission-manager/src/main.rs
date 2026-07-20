pub mod policy;
pub mod storage;

use tonic::{transport::Server, Request, Response, Status};
use std::sync::Arc;

pub mod proto {
    tonic::include_proto!("niraos.permissions.v1");
}

use proto::permissions_service_server::{PermissionsService, PermissionsServiceServer};
use proto::{CapabilityRequest, CapabilityResponse};

pub struct PermissionServer {
    engine: Arc<policy::PolicyEngine>,
}

#[tonic::async_trait]
impl PermissionsService for PermissionServer {
    async fn request_capability(
        &self,
        request: Request<CapabilityRequest>,
    ) -> Result<Response<CapabilityResponse>, Status> {
        let req = request.into_inner();
        
        let decision = self
            .engine
            .evaluate_capability(&req.capability, &req.resource)
            .await
            .map_err(|error| Status::invalid_argument(error.to_string()))?;
        
        Ok(Response::new(CapabilityResponse {
            decision,
            scope: "session".to_string(),
        }))
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("Starting NiraOS Permission Manager v0.1.0...");
    let db = storage::init_db()?;
    let engine = Arc::new(policy::PolicyEngine::new(Arc::new(std::sync::Mutex::new(db))));

    let incoming = sys_utils::uds::bind_uds("permissions").await?;
    let server = PermissionServer { engine };

    println!("Permission Manager ready at /run/niraos/permissions.sock");
    
    Server::builder()
        .add_service(PermissionsServiceServer::new(server))
        .serve_with_incoming(incoming)
        .await?;
        
    println!("Permission Manager shutting down.");
    Ok(())
}
