package com.flaxplayer.flax.download

import okhttp3.OkHttpClient
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

/**
 * Accepts any certificate, for a host the user has vouched for: the local
 * network target, or a server with "Verify certificates" off. Dart decides
 * which (acceptsAnyCertificate in lib/services/network/certificate_trust.dart)
 * and flags those requests; every other request verifies.
 *
 * Redirects are not followed, so a trusted request cannot be led to another
 * host, which has to verify.
 */
fun OkHttpClient.Builder.trustingAnyCertificate(): OkHttpClient.Builder {
    val trustAll = object : X509TrustManager {
        override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
        override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
        override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
    }
    val sslContext = SSLContext.getInstance("TLS")
    sslContext.init(null, arrayOf<TrustManager>(trustAll), SecureRandom())
    return sslSocketFactory(sslContext.socketFactory, trustAll)
        .hostnameVerifier { _, _ -> true }
        .followRedirects(false)
        .followSslRedirects(false)
}
