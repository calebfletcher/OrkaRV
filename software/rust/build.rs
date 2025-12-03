fn main() {
    cc::Build::new().file("boot.S").compile("boot");

    println!("cargo::rerun-if-changed=linker.ld");
}
