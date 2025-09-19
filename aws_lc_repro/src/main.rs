use std::io::Write;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut roots = rustls::RootCertStore::empty();
    for cert in rustls_native_certs::load_native_certs().expect("could not load platform certs") {
        roots.add(cert).unwrap();
    }

    let config = rustls::ClientConfig::builder()
        .with_root_certificates(roots)
        .with_no_client_auth();

    let server_name = "example.com".try_into()?;
    let mut conn = rustls::ClientConnection::new(std::sync::Arc::new(config), server_name)?;
    let mut sock = std::net::TcpStream::connect("example.com:443")?;
    let mut tls = rustls::Stream::new(&mut conn, &mut sock);

    // Force handshake
    tls.write(b"")?;

    if conn.fips() {
        println!("Connection is using FIPS mode");
    } else {
        println!("Connection is NOT using FIPS mode");
    }

    if let Some(certs) = conn.peer_certificates() {
        println!("Peer certificates found: {} certificate(s)", certs.len());
        for (i, cert) in certs.iter().enumerate() {
            println!("Certificate {}: {} bytes", i, cert.len());
        }
        println!("Connection established successfully using rustls");
    } else {
        println!("No peer certificates found");
    }

    Ok(())
}
