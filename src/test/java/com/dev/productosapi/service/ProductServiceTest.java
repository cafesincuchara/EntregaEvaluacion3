package com.dev.productosapi.service;

import com.dev.productosapi.model.Product;
import com.dev.productosapi.repository.ProductRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ProductServiceTest {

    @Mock
    private ProductRepository repository;

    @InjectMocks
    private ProductService service;

    @Test
    void getAll_ShouldReturnAllProducts() {
        Product p1 = new Product();
        p1.setId(UUID.randomUUID());
        p1.setName("Laptop");
        p1.setPrice(1500.0);

        Product p2 = new Product();
        p2.setId(UUID.randomUUID());
        p2.setName("Mouse");
        p2.setPrice(25.0);

        when(repository.findAll()).thenReturn(List.of(p1, p2));

        List<Product> result = service.getAll();

        assertEquals(2, result.size());
        verify(repository, times(1)).findAll();
    }

    @Test
    void findById_WhenProductExists_ShouldReturnProduct() {
        UUID id = UUID.randomUUID();
        Product p = new Product();
        p.setId(id);
        p.setName("Monitor");
        p.setPrice(300.0);

        when(repository.findById(id)).thenReturn(Optional.of(p));

        Product result = service.findById(id);

        assertEquals("Monitor", result.getName());
        assertEquals(300.0, result.getPrice());
        verify(repository, times(1)).findById(id);
    }

    @Test
    void findById_WhenProductDoesNotExist_ShouldThrowException() {
        UUID id = UUID.randomUUID();
        when(repository.findById(id)).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () -> service.findById(id));
        assertTrue(ex.getMessage().contains("no encontrado"));
        verify(repository, times(1)).findById(id);
    }

    @Test
    void saveProduct_ShouldReturnSavedProduct() {
        Product p = new Product();
        p.setId(UUID.randomUUID());
        p.setName("Teclado");
        p.setPrice(80.0);

        when(repository.save(p)).thenReturn(p);

        Product result = service.saveProduct(p);

        assertEquals("Teclado", result.getName());
        verify(repository, times(1)).save(p);
    }

    @Test
    void updateProduct_WhenProductExists_ShouldUpdateAndReturn() {
        UUID id = UUID.randomUUID();
        Product existing = new Product();
        existing.setId(id);
        existing.setName("Teclado");
        existing.setPrice(80.0);

        Product details = new Product();
        details.setName("Teclado Mecanico");
        details.setPrice(120.0);

        when(repository.findById(id)).thenReturn(Optional.of(existing));
        when(repository.save(existing)).thenReturn(existing);

        Product result = service.updateProduct(id, details);

        assertEquals("Teclado Mecanico", result.getName());
        assertEquals(120.0, result.getPrice());
        verify(repository, times(1)).findById(id);
        verify(repository, times(1)).save(existing);
    }

    @Test
    void updateProduct_WhenProductDoesNotExist_ShouldThrowException() {
        UUID id = UUID.randomUUID();
        when(repository.findById(id)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.updateProduct(id, new Product()));
        verify(repository, times(1)).findById(id);
        verify(repository, never()).save(any());
    }

    @Test
    void deleteById_WhenProductExists_ShouldDelete() {
        UUID id = UUID.randomUUID();
        when(repository.existsById(id)).thenReturn(true);

        service.deleteById(id);

        verify(repository, times(1)).existsById(id);
        verify(repository, times(1)).deleteById(id);
    }

    @Test
    void deleteById_WhenProductDoesNotExist_ShouldThrowException() {
        UUID id = UUID.randomUUID();
        when(repository.existsById(id)).thenReturn(false);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> service.deleteById(id));
        assertTrue(ex.getMessage().contains("no existe"));
        verify(repository, times(1)).existsById(id);
        verify(repository, never()).deleteById(any());
    }

    @Test
    void saveProduct_WhenPriceIsNegative_ShouldThrowException() {
        Product p = new Product();
        p.setId(UUID.randomUUID());
        p.setName("Test");
        p.setPrice(-50.0);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> service.saveProduct(p));
        assertTrue(ex.getMessage().contains("negativo"));
        verify(repository, never()).save(any());
    }

    @Test
    void updateProduct_WhenPriceIsNegative_ShouldThrowException() {
        UUID id = UUID.randomUUID();
        Product details = new Product();
        details.setName("Teclado");
        details.setPrice(-10.0);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> service.updateProduct(id, details));
        assertTrue(ex.getMessage().contains("negativo"));
        verify(repository, never()).save(any());
        verify(repository, never()).findById(any());
    }
}
