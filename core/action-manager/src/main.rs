pub mod actions;

use tonic::{
    transport::{Channel, Server},
    Request, Response, Status,
};

pub mod proto {
    tonic::include_proto!("niraos.actions.v1");
}

pub mod permissions_proto {
    tonic::include_proto!("niraos.permissions.v1");
}

use permissions_proto::permissions_service_client::PermissionsServiceClient;
use permissions_proto::CapabilityRequest;
use proto::action_service_server::{ActionService, ActionServiceServer};
use proto::{ActionRequest, ActionResponse};

pub struct ActionManagerServer {
    permissions_client: PermissionsServiceClient<Channel>,
}

#[tonic::async_trait]
impl ActionService for ActionManagerServer {
    async fn execute_action(
        &self,
        request: Request<ActionRequest>,
    ) -> Result<Response<ActionResponse>, Status> {
        let req = request.into_inner();
        let mut client = self.permissions_client.clone();

        // Bind the permission decision to the concrete resource that will be
        // touched. Unsupported or malformed requests never reach the policy
        // service and therefore cannot create misleading audit entries.
        let resource = match req.action_id.as_str() {
            "filesystem.move" => match req.parameters.get("source") {
                Some(value) => value.clone(),
                None => {
                    return Ok(Response::new(ActionResponse {
                        success: false,
                        message: "filesystem.move requires a source parameter".to_string(),
                    }))
                }
            },
            "desktop.wallpaper.change" => match req.parameters.get("path") {
                Some(value) => value.clone(),
                None => {
                    return Ok(Response::new(ActionResponse {
                        success: false,
                        message: "desktop.wallpaper.change requires a path parameter".to_string(),
                    }))
                }
            },
            _ => {
                return Ok(Response::new(ActionResponse {
                    success: false,
                    message: format!("unsupported action: {}", req.action_id),
                }))
            }
        };

        let perm_req = tonic::Request::new(CapabilityRequest {
            capability: req.action_id.clone(),
            resource: resource.clone(),
            reason: req.reason.clone(),
        });

        match client.request_capability(perm_req).await {
            Ok(response) => {
                let decision = response.into_inner().decision;
                if decision == "allowed" {
                    if req.action_id == "filesystem.move" {
                        let source = resource;
                        let destination = match req.parameters.get("destination") {
                            Some(value) => value.clone(),
                            None => {
                                return Ok(Response::new(ActionResponse {
                                    success: false,
                                    message: "filesystem.move requires a destination parameter"
                                        .to_string(),
                                }))
                            }
                        };
                        match actions::filesystem::move_file_safely(&source, &destination).await {
                            Ok(()) => Ok(Response::new(ActionResponse {
                                success: true,
                                message: format!("moved {} to {}", source, destination),
                            })),
                            Err(error) => Ok(Response::new(ActionResponse {
                                success: false,
                                message: format!("action failed: {error}"),
                            })),
                        }
                    } else if req.action_id == "desktop.wallpaper.change" {
                        match actions::desktop::change_wallpaper(&resource).await {
                            Ok(()) => Ok(Response::new(ActionResponse {
                                success: true,
                                message: "wallpaper updated".to_string(),
                            })),
                            Err(error) => Ok(Response::new(ActionResponse {
                                success: false,
                                message: format!("action failed: {error}"),
                            })),
                        }
                    } else {
                        unreachable!("action id was validated before policy evaluation")
                    }
                } else {
                    Ok(Response::new(ActionResponse {
                        success: false,
                        message: format!("permission denied for action {}", req.action_id),
                    }))
                }
            }
            Err(e) => Ok(Response::new(ActionResponse {
                success: false,
                message: format!("failed to verify permissions: {e}"),
            })),
        }
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("Starting NiraOS Action Manager...");

    // `After=` orders process start but does not guarantee that the socket is
    // already accepting connections. Wait for bounded readiness and fail the
    // unit honestly if the security service never becomes available.
    let mut last_error = None;
    let mut channel = None;
    for _ in 0..20 {
        match sys_utils::uds::connect_uds("permissions").await {
            Ok(connected) => {
                channel = Some(connected);
                break;
            }
            Err(error) => {
                last_error = Some(error);
                tokio::time::sleep(std::time::Duration::from_millis(250)).await;
            }
        }
    }
    let channel = channel.ok_or_else(|| {
        anyhow::anyhow!(
            "permission manager did not become ready: {}",
            last_error
                .map(|error| error.to_string())
                .unwrap_or_else(|| "unknown connection error".to_string())
        )
    })?;
    let permissions_client = PermissionsServiceClient::new(channel);

    let incoming = sys_utils::uds::bind_uds("actions").await?;
    let server = ActionManagerServer { permissions_client };

    println!("Action Manager ready at /run/niraos/actions.sock");

    Server::builder()
        .add_service(ActionServiceServer::new(server))
        .serve_with_incoming(incoming)
        .await?;

    println!("Action Manager shutting down.");
    Ok(())
}
