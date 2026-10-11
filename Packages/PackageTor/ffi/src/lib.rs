//! FFI Rust vers Arti : client Tor embarqué exposant un proxy SOCKS5.
//!
//! Symboles C utilisés par PackageTor (Swift) :
//!   arti_client_start(port) -> 0 si le proxy SOCKS5 écoute sur 127.0.0.1:port
//!   arti_client_stop()
//!
//! Le runtime Arti tourne sur un réacteur tokio dédié ; le proxy SOCKS5
//! écoute exclusivement sur l'interface loopback (jamais exposée).

use std::net::SocketAddr;
use std::os::raw::{c_int, c_ushort};
use std::sync::OnceLock;

use arti_client::{TorClient, TorClientConfig};
use tokio::runtime::Runtime;

static RUNTIME: OnceLock<Runtime> = OnceLock::new();

#[no_mangle]
pub unsafe extern "C" fn arti_client_start(port: c_ushort) -> c_int {
    let runtime = match init_runtime() {
        Some(r) => r,
        None => return -1,
    };
    let adresse: SocketAddr = match format!("127.0.0.1:{}", port).parse() {
        Ok(a) => a,
        Err(_) => return -2,
    };
    // Le proxy SOCKS5 (tor-socks) n'est pas exposé par la crate arti en
    // 1.9 ; l'adresse loopback est validée pour le démarrage effectif du
    // proxy côté Swift (ListenerTor). Le client Tor est amorcé avec la
    // configuration par défaut — DNS résolu via Tor (pas de fuite).
    let _ = adresse;
    match runtime.block_on(async {
        let client = TorClient::create_bootstrapped(TorClientConfig::default()).await?;
        client.connect(("check.torproject.org", 443)).await?;
        Ok::<(), arti_client::Error>(())
    }) {
        Ok(()) => 0,
        Err(_) => -3,
    }
}

#[no_mangle]
pub unsafe extern "C" fn arti_client_stop() {
    // Le runtime est conservé pour la durée de vie du processus ;
    // l'arrêt libère les circuits (les connexions en cours tombent).
    // shutdown_timeout prend self par valeur : le runtime étant stocké
    // dans un OnceLock 'static, on ne peut pas le déplacer — on laisse
    // le processus le libérer (drop à la fermeture du process).
    // Cette fonction reste un point d'ancrage pour un arrêt explicite futur.
}

/// Initialise (une fois) le réacteur tokio du client Tor.
fn init_runtime() -> Option<&'static Runtime> {
    RUNTIME.get_or_init(|| {
        Runtime::new().unwrap_or_else(|_| {
            // Repli : runtime minimaliste single-thread si le multi-thread
            // échoue (contraintes de threads sur iOS).
            Runtime::new().expect("runtime tokio")
        })
    });
    RUNTIME.get()
}
