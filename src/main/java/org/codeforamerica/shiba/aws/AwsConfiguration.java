package org.codeforamerica.shiba.aws;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import software.amazon.awssdk.auth.credentials.InstanceProfileCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.cloudwatch.CloudWatchClient;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueResponse;
import software.amazon.awssdk.services.ses.SesClient;

import jakarta.annotation.PostConstruct;
import java.util.HashMap;
import java.util.Map;

/**
 * AWS service configuration for Lambda deployment.
 *
 * Provides beans for AWS SDK clients (S3, Secrets Manager, SES, CloudWatch)
 * and handles loading secrets from AWS Secrets Manager.
 */
@Configuration
@Profile("aws")
public class AwsConfiguration {

    @Value("${cloud.aws.region.static:us-east-1}")
    private String region;

    @Value("${shiba.secrets.db-credentials-arn:}")
    private String dbCredentialsArn;

    @Value("${shiba.secrets.application-secrets-arn:}")
    private String applicationSecretsArn;

    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * S3 client for document storage and static assets.
     */
    @Bean
    public S3Client s3Client() {
        return S3Client.builder()
                .region(Region.of(region))
                .credentialsProvider(InstanceProfileCredentialsProvider.create())
                .build();
    }

    /**
     * Secrets Manager client for retrieving sensitive configuration.
     */
    @Bean
    public SecretsManagerClient secretsManagerClient() {
        return SecretsManagerClient.builder()
                .region(Region.of(region))
                .credentialsProvider(InstanceProfileCredentialsProvider.create())
                .build();
    }

    /**
     * SES client for sending emails.
     */
    @Bean
    @ConditionalOnProperty(name = "shiba.features.email-notifications", havingValue = "true", matchIfMissing = true)
    public SesClient sesClient() {
        return SesClient.builder()
                .region(Region.of(region))
                .credentialsProvider(InstanceProfileCredentialsProvider.create())
                .build();
    }

    /**
     * CloudWatch client for custom metrics.
     */
    @Bean
    public CloudWatchClient cloudWatchClient() {
        return CloudWatchClient.builder()
                .region(Region.of(region))
                .credentialsProvider(InstanceProfileCredentialsProvider.create())
                .build();
    }

    /**
     * Load database credentials from Secrets Manager and set as system properties.
     *
     * This allows Spring Boot to use the credentials from Secrets Manager
     * for database connection configuration.
     */
    @PostConstruct
    public void loadDatabaseCredentials() {
        if (dbCredentialsArn != null && !dbCredentialsArn.isEmpty()) {
            try {
                SecretsManagerClient client = secretsManagerClient();
                GetSecretValueRequest request = GetSecretValueRequest.builder()
                        .secretId(dbCredentialsArn)
                        .build();
                GetSecretValueResponse response = client.getSecretValue(request);
                String secretString = response.secretString();

                JsonNode secretJson = objectMapper.readTree(secretString);

                // Set database connection properties
                System.setProperty("DB_HOST", secretJson.get("host").asText());
                System.setProperty("DB_PORT", secretJson.get("port").asText());
                System.setProperty("DB_NAME", secretJson.get("dbname").asText());
                System.setProperty("DB_USERNAME", secretJson.get("username").asText());
                System.setProperty("DB_PASSWORD", secretJson.get("password").asText());

            } catch (Exception e) {
                throw new RuntimeException("Failed to load database credentials from Secrets Manager", e);
            }
        }
    }

    /**
     * Load application secrets from Secrets Manager.
     *
     * Returns a map of secret keys to values that can be used throughout
     * the application for API keys, encryption keys, etc.
     */
    @Bean
    public Map<String, String> applicationSecrets() {
        if (applicationSecretsArn == null || applicationSecretsArn.isEmpty()) {
            return new HashMap<>();
        }

        try {
            SecretsManagerClient client = secretsManagerClient();
            GetSecretValueRequest request = GetSecretValueRequest.builder()
                    .secretId(applicationSecretsArn)
                    .build();
            GetSecretValueResponse response = client.getSecretValue(request);
            String secretString = response.secretString();

            JsonNode secretJson = objectMapper.readTree(secretString);
            Map<String, String> secrets = new HashMap<>();

            secretJson.fields().forEachRemaining(entry -> {
                secrets.put(entry.getKey(), entry.getValue().asText());
            });

            return secrets;

        } catch (Exception e) {
            throw new RuntimeException("Failed to load application secrets from Secrets Manager", e);
        }
    }
}
