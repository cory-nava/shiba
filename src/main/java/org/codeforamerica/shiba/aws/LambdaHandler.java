package org.codeforamerica.shiba.aws;

import org.springframework.cloud.function.adapter.aws.SpringBootRequestHandler;

/**
 * AWS Lambda handler for Spring Boot application.
 *
 * This handler integrates Spring Cloud Function with AWS Lambda,
 * allowing the Spring Boot application to run serverlessly.
 *
 * The handler is invoked by Lambda and delegates to the Spring Boot
 * application context for request processing.
 */
public class LambdaHandler extends SpringBootRequestHandler<Object, Object> {
    // Spring Cloud Function handles the lifecycle and request routing
}
