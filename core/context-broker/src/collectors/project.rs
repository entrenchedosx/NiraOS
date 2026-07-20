use std::path::Path;

pub fn detect_project(path: &str) -> String {
    let p = Path::new(path);
    let mut ctx = String::from("Project Context:\n");
    if p.join(".git").exists() { ctx.push_str("- Git Repository\n"); }
    if p.join("Cargo.toml").exists() { ctx.push_str("- Rust (Cargo) Project\n"); }
    if p.join("CMakeLists.txt").exists() { ctx.push_str("- C++ (CMake) Project\n"); }
    if p.join("package.json").exists() { ctx.push_str("- Node.js Project\n"); }
    ctx
}
