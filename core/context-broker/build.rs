fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=../../ipc/proto/v1");

    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .compile(&["../../ipc/proto/v1/common.proto"], &["../../ipc/proto"])?;

    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .extern_path(".niraos.common.v1", "crate::proto::common")
        .compile(
            &[
                "../../ipc/proto/v1/context.proto",
            ],
            &["../../ipc/proto"],
        )?;
    Ok(())
}
