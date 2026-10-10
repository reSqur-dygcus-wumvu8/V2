//! FFI Rust vers tor C (crate libtor) : daemon Tor embarqué avec
//! restriction du pays de sortie (directive ExitNodes {cc} + StrictNodes).
//!
//! Symboles C utilisés par PackageTor (Swift) :
//!   torc_client_start(port, pays) -> 0 si le proxy SOCKS5 écoute
//!   torc_client_stop()

use std::ffi::c_int;
use std::os::raw::c_ushort;

#[no_mangle]
pub extern "C" fn torc_client_start(port: c_ushort, pays: *const std::os::raw::c_char) -> c_int {
    use libtor::{TorFlag, Tor};
    use std::str::FromStr;

    let pays = unsafe {
        if pays.is_null() {
            return -1;
        }
        match std::ffi::CStr::from_ptr(pays).to_str() {
            Ok(p) => p.to_string(),
            Err(_) => return -2,
        }
    };

    // Restriction de sortie : ExitNodes {cc} + StrictNodes — réduit
    // l'anonymat (avertissement affiché côté interface).
    let mut tor = Tor::new();
    tor.flag(TorFlag::SocksPort(port))
        .flag(TorFlag::DataDirectory("/tmp/osint-tor".into()))
        .flag(TorFlag::LogToStdout(false));
    // La restriction pays utilise la chaîne de configuration brute.
    let config = format!("ExitNodes {{{}}}\nStrictNodes 1", pays);
    tor.flag(TorFlag::Custom(config));

    match tor.start() {
        Ok(_) => 0,
        Err(_) => -3,
    }
}

#[no_mangle]
pub extern "C" fn torc_client_stop() {
    // libtor tourne dans le processus ; l'arrêt coupe le daemon embarqué
    // (les connexions en cours tombent proprement).
    std::process::Command::new("pkill")
        .arg("-f")
        .arg("osint-tor")
        .status()
        .ok();
}
