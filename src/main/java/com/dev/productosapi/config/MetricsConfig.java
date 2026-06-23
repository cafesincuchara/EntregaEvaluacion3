package com.dev.productosapi.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MetricsConfig {

    @Bean
    public Counter requestCounter(MeterRegistry registry) {
        return Counter.builder("productosapi.requests.total")
            .description("Total de peticiones HTTP")
            .register(registry);
    }

    @Bean
    public Counter errorCounter(MeterRegistry registry) {
        return Counter.builder("productosapi.errors.total")
            .description("Total de errores HTTP")
            .register(registry);
    }

    @Bean
    public Counter productCreatedCounter(MeterRegistry registry) {
        return Counter.builder("productosapi.products.created")
            .description("Total de productos creados")
            .register(registry);
    }
}
