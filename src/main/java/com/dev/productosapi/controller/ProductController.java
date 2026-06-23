package com.dev.productosapi.controller;

import com.dev.productosapi.model.Product;
import com.dev.productosapi.service.ProductService;
import io.micrometer.core.instrument.Counter;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("api/v1/products")
public class ProductController {

    private final ProductService service;

    @Autowired(required = false)
    private Counter requestCounter;

    @Autowired(required = false)
    private Counter productCreatedCounter;

    public ProductController(ProductService service) {
        this.service = service;
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
    public ResponseEntity<Product> createProduct(@Valid @RequestBody Product product) {
        if (requestCounter != null) requestCounter.increment();
        if (productCreatedCounter != null) productCreatedCounter.increment();
        return new ResponseEntity<>(service.saveProduct(product), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Product> updateProduct(@PathVariable UUID id, @Valid @RequestBody Product product) {
        if (requestCounter != null) requestCounter.increment();
        return ResponseEntity.ok(service.updateProduct(id, product));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProductById(@PathVariable UUID id) {
        if (requestCounter != null) requestCounter.increment();
        service.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}