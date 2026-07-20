use sysinfo::System;

pub fn collect_top_processes() -> String {
    let mut sys = System::new_all();
    sys.refresh_all();
    let mut processes: Vec<_> = sys.processes().values().collect();
    processes.sort_by(|left, right| {
        right
            .cpu_usage()
            .partial_cmp(&left.cpu_usage())
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let summary = processes
        .into_iter()
        .take(5)
        .map(|process| format!("{} ({:.1}% CPU)", process.name().to_string(), process.cpu_usage()))
        .collect::<Vec<_>>();
    format!("Top processes: {}", summary.join(", "))
}
