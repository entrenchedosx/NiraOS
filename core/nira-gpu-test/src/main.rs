use serde::Serialize;
use std::process::Command;

#[derive(Serialize)]
struct GpuReport {
    vulkan_active: bool,
    cuda_active: bool,
    opengl_version: String,
}

fn main() {
    let report = GpuReport {
        vulkan_active: Command::new("vulkaninfo").output().is_ok(),
        cuda_active: Command::new("nvidia-smi").output().is_ok(),
        opengl_version: "Unknown".to_string(), // Hook glxinfo if Xwayland present
    };
    
    println!("{}", serde_json::to_string_pretty(&report).unwrap());
}
