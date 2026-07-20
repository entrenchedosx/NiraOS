fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=../../ipc/proto/v1");

    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .compile(
            &[
                "../../ipc/proto/v1/actions.proto",
                "../../ipc/proto/v1/permissions.proto",
            ],
            &["../../ipc/proto"],
        )?;
    Ok(())
}
