fn main() {
    cc::Build::new().file("boot.S").compile("boot");
}
