fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=../../ipc/proto/v1");

    // Generate common package first for extern_path reference
    tonic_build::configure()
        .build_server(false)
        .build_client(false)
        .compile(&["../../ipc/proto/v1/common.proto"], &["../../ipc/proto"])?;

    // Generate ai service, mapping common references to our module
    tonic_build::configure()
        .build_server(false)
        .build_client(true)
        .extern_path(".niraos.common.v1", "crate::common")
        .compile(&["../../ipc/proto/v1/ai.proto"], &["../../ipc/proto"])?;

    Ok(())
}
