use sysinfo::System;

pub fn collect_hardware_context() -> String {
    let mut sys = System::new_all();
    sys.refresh_all();
    format!(
        "CPU: {} | RAM Used: {} MB / {} MB", 
        sys.cpus().first().map(|c| c.brand()).unwrap_or("Unknown"),
        sys.used_memory() / 1024 / 1024,
        sys.total_memory() / 1024 / 1024
    )
}
