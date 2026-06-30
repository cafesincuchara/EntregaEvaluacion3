package com.dev.productosapi.controller;

import com.dev.productosapi.model.Product;
import com.dev.productosapi.model.ProductRequest;
import com.dev.productosapi.service.ProductService;
import io.micrometer.core.instrument.Counter;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("api/v1/products")
public class ProductController {

    private final ProductService service;
    private final Counter requestCounter;
    private final Counter productCreatedCounter;

    public ProductController(ProductService service, Counter requestCounter, Counter productCreatedCounter) {
        this.service = service;
        this.requestCounter = requestCounter;
        this.productCreatedCounter = productCreatedCounter;
    }

    @GetMapping
    public ResponseEntity<List<Product>> getAllProduct() {
        if (requestCounter != null) requestCounter.increment();
        return ResponseEntity.ok(service.getAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Product> getProductById(@PathVariable UUID id) {
        if (requestCounter != null) requestCounter.increment();
        return ResponseEntity.ok(service.findById(id));
    }

    @PostMapping
    public ResponseEntity<Product> createProduct(@Valid @RequestBody ProductRequest request) {
        if (requestCounter != null) requestCounter.increment();
        if (productCreatedCounter != null) productCreatedCounter.increment();
        return new ResponseEntity<>(service.saveProduct(request.toEntity()), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Product> updateProduct(@PathVariable UUID id, @Valid @RequestBody ProductRequest request) {
        if (requestCounter != null) requestCounter.increment();
        return ResponseEntity.ok(service.updateProduct(id, request.toEntity()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProductById(@PathVariable UUID id) {
        if (requestCounter != null) requestCounter.increment();
        service.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}