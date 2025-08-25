fn main() {
    println!(
        "AWS LC FIPS Version: {}",
        unsafe { std::ffi::CStr::from_ptr(aws_lc_fips_sys::awslc_version_string()) }
            .to_str()
            .expect("version string is not a valid utf-8 string")
    );
}