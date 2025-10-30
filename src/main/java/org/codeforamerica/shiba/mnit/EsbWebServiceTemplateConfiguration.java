package org.codeforamerica.shiba.mnit;

import java.nio.charset.StandardCharsets;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.apache.commons.codec.binary.Base64;
import org.apache.hc.client5.http.config.RequestConfig;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManagerBuilder;
import org.apache.hc.client5.http.io.HttpClientConnectionManager;
import org.apache.hc.client5.http.ssl.SSLConnectionSocketFactory;
import org.apache.hc.core5.http.HttpHeaders;
import org.apache.hc.core5.http.message.BasicHeader;
import org.apache.hc.core5.ssl.SSLContextBuilder;
import org.apache.hc.core5.util.Timeout;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.webservices.client.WebServiceTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.oxm.jaxb.Jaxb2Marshaller;
import org.springframework.ws.client.core.WebServiceTemplate;
import org.springframework.ws.transport.http.HttpComponents5MessageSender;

@Configuration
public class EsbWebServiceTemplateConfiguration {
  @Bean
  WebServiceTemplate filenetWebServiceTemplate(WebServiceTemplateBuilder webServiceTemplateBuilder,
      SSLContextBuilder sslContextBuilder,
      @Value("${mnit-filenet.username}") String username,
      @Value("${mnit-filenet.password}") String password,
      @Value("${mnit-filenet.jaxb-context-path}") String jaxbContextPath,
      @Value("${mnit-filenet.upload-url}") String uploadUrl,
      @Value("${mnit-filenet.timeout-seconds}") long timeoutSeconds)
      throws KeyManagementException, NoSuchAlgorithmException {

    Jaxb2Marshaller jaxb2Marshaller = new Jaxb2Marshaller();
    jaxb2Marshaller.setContextPath(jaxbContextPath);
    String auth = username + ":" + password;
    byte[] encodedAuth = Base64.encodeBase64(auth.getBytes(StandardCharsets.ISO_8859_1));
    int timeoutMillis = (int) TimeUnit.MILLISECONDS.convert(timeoutSeconds, TimeUnit.SECONDS);
    Timeout timeout = Timeout.ofMilliseconds(timeoutMillis);
    RequestConfig requestConfig = RequestConfig.custom()
        .setConnectionRequestTimeout(timeout)
        .setConnectTimeout(timeout)
        .setResponseTimeout(timeout)
        .build();

    SSLConnectionSocketFactory sslSocketFactory = new SSLConnectionSocketFactory(sslContextBuilder.build());
    HttpClientConnectionManager connectionManager = PoolingHttpClientConnectionManagerBuilder.create()
        .setSSLSocketFactory(sslSocketFactory)
        .build();

    CloseableHttpClient httpClient = HttpClients.custom()
        .setConnectionManager(connectionManager)
        .setDefaultHeaders(
            List.of(new BasicHeader(HttpHeaders.AUTHORIZATION, "Basic " + new String(encodedAuth))))
        .setDefaultRequestConfig(requestConfig)
        .build();

    HttpComponents5MessageSender messageSender = new HttpComponents5MessageSender(httpClient);

    return webServiceTemplateBuilder
        .setDefaultUri(uploadUrl)
        .setMarshaller(jaxb2Marshaller)
        .setUnmarshaller(jaxb2Marshaller)
        .messageSenders(messageSender)
        .build();
  }
}
