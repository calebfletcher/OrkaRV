fn main() {
    println!("cargo::rerun-if-changed=link.x");
    println!("cargo::rustc-link-arg=-Tlink.x");
    // Cargo only adds the workspace dir as a default search path so we need
    // to add the manifest dir manually
    println!(
        "cargo::rustc-link-search={}",
        std::env::var("CARGO_MANIFEST_DIR").unwrap()
    );
}
