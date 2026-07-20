fn main() {
    let proto_root = "../../ipc/proto";
    tonic_build::configure()
        .compile(
            &[&format!("{}/v1/settings.proto", proto_root)],
            &[proto_root],
        )
        .unwrap_or_else(|e| panic!("failed to compile settings.proto: {e}"));
}
