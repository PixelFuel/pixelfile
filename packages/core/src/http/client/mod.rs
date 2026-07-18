mod url;
pub mod v2;
pub mod v3;

pub use v2::LsHttpClientV2;
pub use v3::LsHttpClientV3;

use crate::http::StatusCodeError;
use crate::{crypto, http, model};
use bytes::Bytes;
use futures_util::StreamExt;
use reqwest::Response;
use serde::{Deserialize, Serialize};
use std::sync::Once;
use thiserror::Error;
use tokio_stream::wrappers::ReceiverStream;

const LAN_NO_PROXY: [&str; 5] = [
    "localhost",
    "127.0.0.1",
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
];

pub enum LsHttpClient {
    V2(LsHttpClientV2),
    V3(LsHttpClientV3),
}

pub enum LsHttpClientVersion {
    V2,
    V3,
}

#[derive(Debug, Error)]
pub enum ClientError {
    #[error(transparent)]
    StatusCode(StatusCodeError),

    #[error(transparent)]
    Reqwest(#[from] reqwest::Error),

    #[error(transparent)]
    Json(#[from] serde_json::Error),

    #[error(transparent)]
    Io(#[from] std::io::Error),

    #[error(transparent)]
    Other(#[from] anyhow::Error),

    #[error("Upload cancelled")]
    Cancelled,
}

impl LsHttpClient {
    pub fn new(
        private_key: &str,
        cert: &str,
        version: LsHttpClientVersion,
        timeout: Option<std::time::Duration>,
    ) -> Result<LsHttpClient, ClientError> {
        let client = match version {
            LsHttpClientVersion::V2 => {
                LsHttpClient::V2(LsHttpClientV2::try_new(&private_key, &cert, timeout)?)
            }
            LsHttpClientVersion::V3 => {
                LsHttpClient::V3(LsHttpClientV3::try_new(&private_key, &cert, timeout)?)
            }
        };

        Ok(client)
    }

    pub async fn register(
        &self,
        protocol: http::dto::ProtocolType,
        ip: &str,
        port: u16,
        payload: http::dto::RegisterDto,
    ) -> Result<ResultWithPublicKey<http::dto::RegisterResponseDto>, ClientError> {
        match self {
            LsHttpClient::V2(client) => {
                let result = client.register(protocol, ip, port, payload.into()).await?;
                Ok(ResultWithPublicKey {
                    public_key: result.public_key,
                    body: result.body.into(),
                })
            }
            LsHttpClient::V3(client) => client.register(protocol, ip, port, payload).await,
        }
    }

    pub async fn prepare_upload(
        &self,
        protocol: http::dto::ProtocolType,
        ip: &str,
        port: u16,
        public_key: Option<String>,
        payload: http::dto::PrepareUploadRequestDto,
        pin: Option<&str>,
    ) -> Result<http::dto::PrepareUploadResult, ClientError> {
        match self {
            LsHttpClient::V2(client) => {
                let result = client
                    .prepare_upload(protocol, ip, port, public_key, payload.into(), pin)
                    .await?;
                Ok(result.into())
            }
            LsHttpClient::V3(client) => {
                client
                    .prepare_upload(protocol, ip, port, public_key, payload)
                    .await
            }
        }
    }

    pub async fn upload(
        &self,
        protocol: http::dto::ProtocolType,
        ip: &str,
        port: u16,
        public_key: Option<String>,
        session_id: &str,
        file_id: &str,
        token: &str,
        content: model::transfer::FileContent,
        progress: impl Fn(u64) + Send + 'static,
        cancel: tokio_util::sync::CancellationToken,
    ) -> Result<(), ClientError> {
        let body = upload_body(content, progress);
        match self {
            LsHttpClient::V2(client) => {
                client
                    .upload(
                        protocol, ip, port, public_key, session_id, file_id, token, body, cancel,
                    )
                    .await
            }
            LsHttpClient::V3(client) => {
                client
                    .upload(
                        protocol, ip, port, public_key, session_id, file_id, token, body, cancel,
                    )
                    .await
            }
        }
    }

    pub async fn cancel(
        &self,
        protocol: http::dto::ProtocolType,
        ip: &str,
        port: u16,
        session_id: &str,
    ) -> Result<(), ClientError> {
        match self {
            LsHttpClient::V2(client) => client.cancel(protocol, ip, port, session_id).await,
            LsHttpClient::V3(client) => client.cancel(protocol, ip, port, session_id).await,
        }
    }
}

/// Builds a streaming request body from the file content, invoking `progress`
/// with the cumulative number of bytes read as each chunk is sent.
pub(super) fn upload_body(
    content: model::transfer::FileContent,
    progress: impl Fn(u64) + Send + 'static,
) -> reqwest::Body {
    let mut sent = 0_u64;
    let stream = ReceiverStream::new(content.into_receiver()).map(move |chunk| {
        sent += chunk.len() as u64;
        progress(sent);
        Ok::<Bytes, anyhow::Error>(chunk)
    });
    reqwest::Body::wrap_stream(stream)
}

pub(super) fn create_reqwest_client(
    private_key: &str,
    cert: &str,
    timeout: Option<std::time::Duration>,
) -> Result<reqwest::Client, ClientError> {
    configure_lan_proxy_bypass();

    let _ = rustls::crypto::ring::default_provider().install_default();

    let identity = {
        let pem = &[cert.as_bytes(), "\n".as_bytes(), private_key.as_bytes()].concat();
        reqwest::Identity::from_pem(pem)?
    };

    let mut builder = reqwest::Client::builder()
        .use_rustls_tls()
        .danger_accept_invalid_certs(true)
        .tls_info(true)
        .identity(identity);

    if let Some(timeout) = timeout {
        builder = builder.timeout(timeout);
    }

    let client = builder.build()?;

    Ok(client)
}

/// Adds local and private IPv4 destinations to the process proxy bypass list.
///
/// Reqwest reads this list while constructing its system proxy matcher. Keeping
/// the existing entries preserves the configured proxy for public destinations.
pub(super) fn configure_lan_proxy_bypass() {
    static CONFIGURE_ONCE: Once = Once::new();

    CONFIGURE_ONCE.call_once(|| {
        let existing = ["NO_PROXY", "no_proxy"]
            .iter()
            .filter_map(|key| std::env::var(key).ok())
            .filter(|value| !value.trim().is_empty())
            .collect::<Vec<_>>()
            .join(",");
        let no_proxy = merge_no_proxy(&existing);

        // Keep both variants aligned for HTTP libraries that prefer either one.
        std::env::set_var("NO_PROXY", &no_proxy);
        std::env::set_var("no_proxy", no_proxy);
    });
}

fn merge_no_proxy(existing: &str) -> String {
    let mut entries = existing
        .split(',')
        .map(str::trim)
        .filter(|entry| !entry.is_empty())
        .map(str::to_owned)
        .collect::<Vec<_>>();

    for required in LAN_NO_PROXY {
        if !entries.iter().any(|entry| entry == required) {
            entries.push(required.to_owned());
        }
    }

    entries.join(",")
}

/// Verifies the certificate from the response.
/// Returns the public key extracted from the certificate.
pub(super) fn verify_cert_from_res(
    response: &Response,
    public_key: Option<String>,
) -> anyhow::Result<String> {
    let tls_info_ext = response
        .extensions()
        .get::<reqwest::tls::TlsInfo>()
        .ok_or_else(|| anyhow::anyhow!("TLS info not found"))?;
    let cert = tls_info_ext
        .peer_certificate()
        .ok_or_else(|| anyhow::anyhow!("Certificate not found"))?;
    crypto::cert::verify_cert_from_der(cert, public_key.as_deref())?;
    let public_key = match public_key {
        Some(public_key) => public_key,
        None => crypto::cert::public_key_from_cert_der(cert)?,
    };
    Ok(public_key)
}

#[derive(Serialize, Deserialize)]
struct ErrorResponse {
    message: String,
}

pub struct ResultWithPublicKey<T> {
    /// The public key extracted from the certificate.
    /// Encoded in PEM format.
    /// Only available in HTTPS mode.
    pub public_key: Option<String>,

    /// The response body.
    pub body: T,
}

pub(super) trait ResponseExt {
    async fn into_error<T>(self) -> Result<T, ClientError>;
}

impl ResponseExt for Response {
    async fn into_error<T>(self) -> Result<T, ClientError> {
        let status = self.status().as_u16();
        let body = self.text().await.unwrap_or_default();
        let message = match serde_json::from_str::<ErrorResponse>(&body) {
            Ok(error) => error.message,
            Err(_) => body,
        };
        Err(ClientError::StatusCode(StatusCodeError {
            status,
            message: if message.is_empty() {
                None
            } else {
                Some(message)
            },
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::merge_no_proxy;

    #[test]
    fn adds_lan_ranges_without_removing_existing_bypasses() {
        let result = merge_no_proxy("example.internal, 203.0.113.8");

        assert_eq!(
            result,
            "example.internal,203.0.113.8,localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
        );
    }

    #[test]
    fn does_not_duplicate_existing_lan_ranges() {
        let result = merge_no_proxy("localhost,192.168.0.0/16");

        assert_eq!(
            result,
            "localhost,192.168.0.0/16,127.0.0.1,10.0.0.0/8,172.16.0.0/12"
        );
    }
}
