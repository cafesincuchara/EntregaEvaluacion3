package com.dev.productosapi.service;

import com.dev.productosapi.model.Product;
import com.dev.productosapi.repository.ProductRepository;
import lombok.AllArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@AllArgsConstructor
public class ProductService {

    private final ProductRepository repository;

    @Transactional(readOnly = true)
    public List<Product> getAll() {
        return repository.findAll();
    }

    @Transactional(readOnly = true)
    public Product findById(UUID id) {
        return repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Producto con ID " + id + " no encontrado."));
    }

    @Transactional
    public Product saveProduct(Product product) {
        return repository.save(product);
    }

    @Transactional
    public Product updateProduct(UUID id, Product productDetails) {
        Product product = findById(id);
        product.setName(productDetails.getName());
        product.setPrice(productDetails.getPrice());

        return repository.save(product);
    }

    @Transactional
    public void deleteById(UUID id) {
        if (!repository.existsById(id)) {
            throw new RuntimeException("Error al eliminar: El ID " + id + " no existe en los registros.");
        }
        repository.deleteById(id);
    }
    public String metodoSinTest() {
        String a = "Esto bajara la cobertura";
        String b = "porque no tiene pruebas unitarias";
        return a + " " + b;
    }
}