use std::fs;
use std::path::Path;
use std::sync::Arc;
use sysinfo::System;
use tokio::sync::RwLock;
use tonic::{transport::Server, Request, Response, Status};

mod proto {
    tonic::include_proto!("niraos.hardware.v1");
}

use proto::hardware_service_server::{HardwareService, HardwareServiceServer};
use proto::{HardwareRequest, HardwareResponse};

pub struct HwServer {
    sys: Arc<RwLock<System>>,
}

impl HwServer {
    fn read_trimmed(path: &Path) -> Option<String> {
        fs::read_to_string(path)
            .ok()
            .map(|value| value.trim().to_string())
    }

    fn battery_percentage(power_supply_root: &Path) -> Option<f32> {
        for entry in fs::read_dir(power_supply_root).ok()?.flatten() {
            let path = entry.path();
            if Self::read_trimmed(&path.join("type")).as_deref() != Some("Battery") {
                continue;
            }
            let Some(capacity) = Self::read_trimmed(&path.join("capacity"))
                .and_then(|value| value.parse::<f32>().ok())
            else {
                continue;
            };
            if (0.0..=100.0).contains(&capacity) {
                return Some(capacity);
            }
        }
        None
    }

    fn cpu_temperature(thermal_root: &Path) -> Option<f32> {
        for entry in fs::read_dir(thermal_root).ok()?.flatten() {
            let path = entry.path();
            let Some(sensor_type) = Self::read_trimmed(&path.join("type")) else {
                continue;
            };
            let sensor_type = sensor_type.to_lowercase();
            if !sensor_type.contains("cpu")
                && !sensor_type.contains("x86_pkg")
                && !sensor_type.contains("soc")
            {
                continue;
            }
            let Some(raw) =
                Self::read_trimmed(&path.join("temp")).and_then(|value| value.parse::<f32>().ok())
            else {
                continue;
            };
            let celsius = if raw.abs() >= 1_000.0 {
                raw / 1_000.0
            } else {
                raw
            };
            if (-50.0..=200.0).contains(&celsius) {
                return Some(celsius);
            }
        }
        None
    }

    fn gpu_info(drm_root: &Path) -> Option<(String, String)> {
        for entry in fs::read_dir(drm_root).ok()?.flatten() {
            let path = entry.path();
            let Some(name) = path.file_name().and_then(|value| value.to_str()) else {
                continue;
            };
            if !name.starts_with("card") || name.contains('-') {
                continue;
            }
            let device_path = path.join("device");
            let Some(vendor) = Self::read_trimmed(&device_path.join("vendor")) else {
                continue;
            };
            let Some(device) = Self::read_trimmed(&device_path.join("device")) else {
                continue;
            };
            let model = format!("PCI {vendor}:{device}");

            let driver_link = device_path.join("driver");
            let driver_target = fs::read_link(&driver_link).ok();
            let driver = driver_target
                .as_ref()
                .and_then(|value| value.file_name())
                .and_then(|value| value.to_str())
                .unwrap_or("unknown")
                .to_string();
            let resolved_driver_path = driver_target.as_ref().map(|target| {
                if target.is_absolute() {
                    target.clone()
                } else {
                    driver_link.parent().unwrap_or(&device_path).join(target)
                }
            });
            let version = resolved_driver_path
                .as_ref()
                .and_then(|value| Self::read_trimmed(&value.join("module/version")));
            let driver_description = version
                .map(|value| format!("{driver} {value}"))
                .unwrap_or(driver);
            return Some((model, driver_description));
        }
        None
    }

    fn capture_info(sys: &mut System, include_thermals: bool) -> HardwareResponse {
        sys.refresh_cpu();
        sys.refresh_memory();

        let cpu_model = sys
            .cpus()
            .first()
            .map(|c| c.brand().to_string())
            .unwrap_or_else(|| "Unknown".to_string());

        let total_mb = sys.total_memory() / 1024 / 1024;
        let used_mb = sys.used_memory() / 1024 / 1024;
        let battery_percent =
            Self::battery_percentage(Path::new("/sys/class/power_supply")).unwrap_or(-1.0);
        let cpu_temp = if include_thermals {
            Self::cpu_temperature(Path::new("/sys/class/thermal")).unwrap_or(-1.0)
        } else {
            -1.0
        };
        let (gpu_model, driver_version) = Self::gpu_info(Path::new("/sys/class/drm"))
            .unwrap_or_else(|| ("Unavailable".to_string(), "Unavailable".to_string()));

        HardwareResponse {
            cpu_model,
            gpu_model,
            driver_version,
            battery_percentage: battery_percent,
            cpu_temp,
            memory_total_mb: total_mb as u64,
            memory_used_mb: used_mb as u64,
        }
    }
}

#[tonic::async_trait]
impl HardwareService for HwServer {
    async fn get_telemetry(
        &self,
        request: Request<HardwareRequest>,
    ) -> Result<Response<HardwareResponse>, Status> {
        let mut sys = self.sys.write().await;
        let response = Self::capture_info(&mut sys, request.into_inner().include_thermals);
        Ok(Response::new(response))
    }
}

#[cfg(test)]
mod tests {
    use super::HwServer;
    use std::fs;
    use std::path::PathBuf;

    fn fixture(name: &str) -> PathBuf {
        let path =
            std::env::temp_dir().join(format!("nira-hardware-test-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&path);
        fs::create_dir_all(&path).unwrap();
        path
    }

    #[test]
    fn reads_real_battery_capacity() {
        let root = fixture("battery");
        let battery = root.join("BAT0");
        fs::create_dir_all(&battery).unwrap();
        fs::write(battery.join("type"), "Battery\n").unwrap();
        fs::write(battery.join("capacity"), "73\n").unwrap();
        assert_eq!(HwServer::battery_percentage(&root), Some(73.0));
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn reads_millidegree_cpu_temperature() {
        let root = fixture("thermal");
        let zone = root.join("thermal_zone0");
        fs::create_dir_all(&zone).unwrap();
        fs::write(zone.join("type"), "x86_pkg_temp\n").unwrap();
        fs::write(zone.join("temp"), "42500\n").unwrap();
        assert_eq!(HwServer::cpu_temperature(&root), Some(42.5));
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn missing_sensors_are_not_reported_as_zero() {
        let root = fixture("missing");
        assert_eq!(HwServer::battery_percentage(&root), None);
        assert_eq!(HwServer::cpu_temperature(&root), None);
        fs::remove_dir_all(root).unwrap();
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("Starting NiraOS Hardware Service...");

    let sys = Arc::new(RwLock::new(System::new_all()));
    let incoming = sys_utils::uds::bind_uds("hardware").await?;
    let server = HwServer { sys };

    println!("Hardware Service ready at /run/niraos/hardware.sock");

    Server::builder()
        .add_service(HardwareServiceServer::new(server))
        .serve_with_incoming(incoming)
        .await?;

    println!("Hardware Service shutting down.");
    Ok(())
}
