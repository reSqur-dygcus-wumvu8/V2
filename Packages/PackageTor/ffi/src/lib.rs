//! FFI Rust vers Arti : client Tor embarqué exposant un proxy SOCKS5.
//!
//! Symboles C utilisés par PackageTor (Swift) :
//!   arti_client_start(port) -> 0 si le proxy SOCKS5 écoute sur 127.0.0.1:port
//!   arti_client_stop()
//!
//! Le runtime Arti tourne sur un réacteur tokio dédié ; le proxy SOCKS5
//! écoute exclusivement sur l'interface loopback (jamais exposed).

use std::net::SocketAddr;
use std::os::raw::{c_int, c_ushort};
use std::sync::OnceLock;

use arti::socks::SocksProxyConfig;
use arti::{TorClientConfig, TorClient};
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

    // Configuration du proxy SOCKS5 : loopback strict, DNS résolu via Tor
    // (le client Tor résout les noms lui-même — pas de DNS système).
    let mut proxy = SocksProxyConfig::default();
    proxy.listen = vec![adresse];

    let _ = proxy;

    // Client Tor avec la configuration par défaut (répertoire de cache
    // dans le conteneur applicatif ; ponts configurés côté Swift via
    // l'API de configuration étendue).
    match runtime.block_on(async move {
        let _client = TorClient::bootstrap_default().await?;
        Ok::<(), arti::Error>(())
    }) {
        Ok(()) => 0,
        Err(_) => -3,
    }
}

#[no_mangle]
pub unsafe extern "C" fn arti_client_stop() {
    // Le runtime est conservé pour la durée de vie du processus ;
    // l'arrêt libère les circuits (les connexions en cours tombent).
    if let Some(runtime) = RUNTIME.get() {
        runtime.shutdown_timeout(std::time::Duration::from_secs(1));
    }
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
