use std::process::Command;
use serde::Serialize;
use std::env;

#[derive(Serialize)]
struct DiagnosticReport {
    kernel: String,
    services: std::collections::HashMap<String, String>,
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let command = args.get(1).map(|s| s.as_str()).unwrap_or("status");

    let services = ["nira-permission", "nira-action", "nira-context", "nira-settings", "nira-ai"];
    
    if command == "status" {
        println!("NiraOS Service Health:");
        for srv in services.iter() {
            let output = Command::new("systemctl").arg("is-active").arg(srv).output().expect("failed systemctl");
            let status = String::from_utf8_lossy(&output.stdout).trim().to_string();
            let icon = if status == "active" { "✓" } else { "✗" };
            println!(" {} {} - {}", icon, srv, status);
        }
    } else if command == "report" || command == "upload" {
        let mut report = DiagnosticReport {
            kernel: String::from_utf8_lossy(&Command::new("uname").arg("-r").output().unwrap().stdout).trim().to_string(),
            services: std::collections::HashMap::new(),
        };
        
        for srv in services.iter() {
            let output = Command::new("systemctl").arg("is-active").arg(srv).output().unwrap();
            let status = String::from_utf8_lossy(&output.stdout).trim().to_string();
            report.services.insert(srv.to_string(), status);
        }
        
        // Scrubbing personal data: We do not include any file paths or conversation history in this report.
        let json = serde_json::to_string_pretty(&report).unwrap();
        
        // Write to file if requested
        let args: Vec<String> = std::env::args().collect();
        if let Some(pos) = args.iter().position(|x| x == "--save") {
            if let Some(path) = args.get(pos + 1) {
                std::fs::write(path, &json).unwrap();
                println!("Report saved to {}", path);
                return;
            }
        }
        
        if command == "upload" {
            println!("--- DIAGNOSTIC PAYLOAD SUMMARY ---");
            println!("NiraOS Version: 0.1.0-alpha");
            println!("Kernel: {}", report.kernel);
            println!("Failed Services: {}", report.services.iter().filter(|(_, v)| *v != "active").count());
            println!("Excluded:");
            println!(" ✓ Files");
            println!(" ✓ Usernames");
            println!(" ✓ AI conversations");
            println!("------------------------------------");
            println!("NiraOS collects ZERO telemetry automatically. The full payload will be formatted into a public GitHub Issue link.");
            println!("Do you consent to generating this bug report link? (Type YES to confirm):");
            
            let mut input = String::new();
            std::io::stdin().read_line(&mut input).unwrap();
            
            if input.trim() == "YES" {
                println!("Generating GitHub Issue link...");
                let encoded_json = urlencoding::encode(&json);
                let url = format!("https://github.com/niraos/niraos/issues/new?title=Alpha%20Bug%20Report&body={}", encoded_json);
                println!("Please open this URL in your browser to submit the bug report:");
                println!("{}", url);
            } else {
                println!("Upload aborted. No data was shared.");
            }
        } else {
            println!("{}", json);
        }
    }

}
