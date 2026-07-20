fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=../../ipc/proto/v1");

    // Generate the shared common package first so that
    // `tonic::include_proto!("niraos.common.v1")` has a file to include.
    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .compile(&["../../ipc/proto/v1/common.proto"], &["../../ipc/proto"])?;

    // Generate the service packages, mapping references to the common package
    // onto the module where the generated common code is included.
    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .extern_path(".niraos.common.v1", "crate::grpc::common")
        .compile(
            &[
                "../../ipc/proto/v1/ai.proto",
                "../../ipc/proto/v1/context.proto",
                "../../ipc/proto/v1/system.proto",
                "../../ipc/proto/v1/actions.proto",
                "../../ipc/proto/v1/permissions.proto",
            ],
            &["../../ipc/proto"],
        )?;
    Ok(())
}
