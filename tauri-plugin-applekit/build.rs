use std::path::PathBuf;
use std::process::Command;
use std::{env, fs};

const LIB_NAME: &str = "CLibAppleKitBridge";
const SWIFT_CODE_DIR: &str = "native_applekit";
const COMMANDS: &[&str] = &[
    "set_user_default",
    "get_user_default",
    "save_keychain",
    "load_keychain",
    "set_theme",
    "show_hud",
    "close_hud"
];

fn main() {
    let static_lib_name = format!("lib{}.a", LIB_NAME);
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());

    // 1. 编译 Swift 库
    let swift_build = Command::new("swift")
        .args(["build", "-c", "release", "--package-path", &SWIFT_CODE_DIR])
        .status()
        .expect("Failed to start Swift build");

    if !swift_build.success() {
        panic!("Swift build failed");
    }

    // 2. 定位生成的静态库
    let swift_lib_path = manifest_dir
        .join(&SWIFT_CODE_DIR)
        .join(".build/release")
        .join(&static_lib_name);

    //println!("cargo:warning=Swift static lib path: {:?}", swift_lib_path);

    // 3. 复制到 target/debug
    let target_dir = manifest_dir.join("target/debug");
    let target_lib = target_dir.join(&static_lib_name);

    fs::create_dir_all(&target_dir).unwrap();
    fs::copy(&swift_lib_path, &target_lib).expect("Failed to copy the Swift library");

    let swift_path = Command::new("xcrun")
        .args(["--find", "swift"])
        .output()
        .expect("Failed to find swift")
        .stdout;
    let swift_path = String::from_utf8(swift_path).unwrap();
    let swift_path = swift_path.trim();
    let toolchain_root = PathBuf::from(swift_path)
        .parent() // bin
        .unwrap()
        .parent() // usr
        .unwrap()
        .to_path_buf();
    let swift_lib_path = toolchain_root.join("lib/swift/macosx");

    // 4. 设置链接参数
    println!("cargo:rustc-link-lib=framework=Foundation");
    println!("cargo:rustc-link-lib=swiftCore");
    println!("cargo:rustc-link-lib=swiftCompatibility50");
    println!("cargo:rustc-link-lib=swiftCompatibility51");
    println!("cargo:rustc-link-lib=swiftCompatibility56");
    println!("cargo:rustc-link-lib=swiftCompatibilityConcurrency");
    println!("cargo:rustc-link-lib=swiftCompatibilityDynamicReplacements");
    println!("cargo:rustc-link-lib=swiftCompatibilityPacks");

    println!("cargo:rustc-link-search={}", target_dir.display());
    println!("cargo:rustc-link-search={}", swift_lib_path.display());
    println!("cargo:rustc-link-lib=static={}", LIB_NAME);
    println!("cargo:rerun-if-changed={}", &SWIFT_CODE_DIR);

    tauri_plugin::Builder::new(COMMANDS)
        .android_path("android")
        .ios_path("ios")
        .build();
}
