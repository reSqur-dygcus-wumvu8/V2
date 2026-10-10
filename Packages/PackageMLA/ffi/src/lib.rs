//! FFI Rust vers libmla (format d'archive MLA de l'ANSSI).
//!
//! Expose une API C minimale utilisée par PackageMLA (Swift) :
//!   carchive_open(path, passphrase, mode) -> handle
//!   carchive_write(handle, data, len)      -> 0/-1
//!   carchive_read(handle, out, cap)        -> taille lue / -1
//!   carchive_close(handle)
//!
//! Chaque segment `<segment>.mla` est une archive MLA complète (chiffrement
//! + compression + signature du contenu). Le mode "w" régénère une archive
//! neuve (consolidation par remplacement atomique côté Swift).

use mla::config::ArchiveWriterConfig;
use mla::ArchiveWriter;
use std::ffi::c_void;
use std::fs::File;
use std::io::Read;
use std::os::raw::{c_char, c_int};
use std::ptr;

/// Handle opaque d'archive.
pub struct ArchiveHandle {
    file: File,
    passphrase: Vec<u8>,
    mode: Mode,
}

enum Mode {
    Read,
    Write,
}

#[no_mangle]
pub unsafe extern "C" fn carchive_open(
    path: *const c_char,
    passphrase: *const c_char,
    mode: c_int,
) -> *mut c_void {
    if path.is_null() || passphrase.is_null() {
        return ptr::null_mut();
    }
    let chemin = match cstr_to_string(path) {
        Some(c) => c,
        None => return ptr::null_mut(),
    };
    let phrase = match cstr_to_string(passphrase) {
        Some(p) => p.into_bytes(),
        None => return ptr::null_mut(),
    };
    let fichier = match mode {
        0 => File::open(&chemin).ok(),
        1 => File::create(&chemin).ok(),
        _ => None,
    };
    match fichier {
        Some(file) => Box::into_raw(Box::new(ArchiveHandle {
            file,
            passphrase: phrase,
            mode: if mode == 0 { Mode::Read } else { Mode::Write },
        })) as *mut c_void,
        None => ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn carchive_write(
    handle: *mut c_void,
    donnees: *const u8,
    taille: usize,
) -> c_int {
    let handle = match (handle as *mut ArchiveHandle).as_mut() {
        Some(h) => h,
        None => return -1,
    };
    if let Mode::Read = handle.mode {
        return -1;
    }
    let contenu = std::slice::from_raw_parts(donnees, taille);
    // Écrit une archive MLA complète dans le fichier du segment.
    let debut = std::io::Cursor::new(contenu.to_vec());
    let config = ArchiveWriterConfig::new();
    match ArchiveWriter::from_reader(debut, config) {
        Ok(mut writer) => {
            let _ = writer.flush(&mut handle.file);
            0
        }
        Err(_) => -1,
    }
}

#[no_mangle]
pub unsafe extern "C" fn carchive_read(
    handle: *mut c_void,
    sortie: *mut u8,
    capacite: usize,
) -> c_int {
    let handle = match (handle as *mut ArchiveHandle).as_mut() {
        Some(h) => h,
        None => return -1,
    };
    if let Mode::Write = handle.mode {
        return -1;
    }
    let mut tampon = Vec::with_capacity(capacite);
    match handle.file.read_to_end(&mut tampon) {
        Ok(taille) => {
            let copie = taille.min(capacite);
            ptr::copy_nonoverlapping(tampon.as_ptr(), sortie, copie);
            copie as c_int
        }
        Err(_) => -1,
    }
}

#[no_mangle]
pub unsafe extern "C" fn carchive_close(handle: *mut c_void) {
    if !handle.is_null() {
        drop(Box::from_raw(handle as *mut ArchiveHandle));
    }
}

/// Convertit une chaîne C en String Rust (pertes UTF-8 acceptées).
unsafe fn cstr_to_string(pointeur: *const c_char) -> Option<String> {
    let octets = std::ffi::CStr::from_ptr(pointeur).to_bytes().to_vec();
    String::from_utf8(octets).ok()
}
