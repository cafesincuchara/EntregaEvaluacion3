package com.dev.productosapi;

import com.amazonaws.xray.spring.aop.XRayEnabled;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@XRayEnabled
public class ProductosapiApplication {

    public static void main(String[] args) {
        SpringApplication.run(ProductosapiApplication.class, args);
    }

}
