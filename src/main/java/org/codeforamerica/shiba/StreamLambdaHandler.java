package org.codeforamerica.shiba;

import com.amazonaws.serverless.exceptions.ContainerInitializationException;
import com.amazonaws.serverless.proxy.internal.LambdaContainerHandler;
import com.amazonaws.serverless.proxy.model.AwsProxyRequest;
import com.amazonaws.serverless.proxy.model.AwsProxyResponse;
import com.amazonaws.serverless.proxy.spring.SpringBootLambdaContainerHandler;
import com.amazonaws.serverless.proxy.spring.SpringBootProxyHandlerBuilder;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestStreamHandler;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Lambda handler that wraps the Spring Boot application using AWS Serverless Java Container.
 * This allows the existing Spring MVC controllers to work seamlessly with AWS API Gateway.
 */
public class StreamLambdaHandler implements RequestStreamHandler {

    private static SpringBootLambdaContainerHandler<AwsProxyRequest, AwsProxyResponse> handler;

    static {
        try {
            // Set initialization timeout to 60 seconds (from default 20s) for cold starts
            LambdaContainerHandler.getContainerConfig().setInitializationTimeout(60_000);

            // Use SpringBootProxyHandlerBuilder to force servlet mode even with WebFlux on classpath
            handler = new SpringBootProxyHandlerBuilder<AwsProxyRequest>()
                .defaultProxy()
                .servletApplication()
                .springBootApplication(ShibaApplication.class)
                .asyncInit() // Use async initialization for better cold start handling
                .buildAndInitialize();
            // Enable response compression
            handler.stripBasePath("");
        } catch (ContainerInitializationException e) {
            // If we fail to initialize the handler, log and rethrow
            e.printStackTrace();
            throw new RuntimeException("Could not initialize Spring Boot application", e);
        }
    }

    @Override
    public void handleRequest(InputStream input, OutputStream output, Context context) throws IOException {
        handler.proxyStream(input, output, context);
    }
}
