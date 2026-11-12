import OmFileIO
import Vapor

/// Preserve HTTP error responses while keeping the signer independent of Vapor.
extension AWSSigner.SigningError: AbortError {}
