//
//  GoogleConfig.swift
//  CliniQi
//

import Foundation

/// Credenciais do app no Google Cloud (OAuth client do tipo **iOS**).
///
/// Como criar (uma vez):
/// 1. console.cloud.google.com › crie um projeto › APIs e serviços › Biblioteca › ative **Google Calendar API**.
/// 2. Tela de consentimento OAuth › tipo **Externo** › em "Usuários de teste" adicione os e-mails que vão usar o app.
/// 3. Credenciais › Criar credenciais › ID do cliente OAuth › tipo **iOS** › Bundle ID `br.decoDev.org.CliniQi`.
/// 4. Cole o "ID do cliente" abaixo (termina em `.apps.googleusercontent.com`).
enum GoogleConfig {
    static let clientID = "797026419413-k9tejpecfr3ce7m5tfd028j8u93o3r5i.apps.googleusercontent.com"

    static let scopes = [
        "openid",
        "email",
        "https://www.googleapis.com/auth/calendar"
    ]

    static var isConfigured: Bool {
        clientID.hasSuffix(".apps.googleusercontent.com") && !clientID.hasPrefix("COLE_AQUI")
    }

    /// Esquema de retorno do OAuth para apps iOS: o client ID invertido.
    static var redirectScheme: String {
        clientID
            .split(separator: ".")
            .reversed()
            .joined(separator: ".")
    }

    static var redirectURI: String { "\(redirectScheme):/oauth2redirect" }
}
