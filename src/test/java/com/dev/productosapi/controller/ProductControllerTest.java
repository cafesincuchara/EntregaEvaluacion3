package com.dev.productosapi.controller;

import com.dev.productosapi.model.Product;
import com.dev.productosapi.service.ProductService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(ProductController.class)
class ProductControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ProductService service;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void getAllProducts_ShouldReturnList() throws Exception {
        Product p = new Product();
        p.setId(UUID.randomUUID());
        p.setName("Laptop");
        p.setPrice(1500.0);

        when(service.getAll()).thenReturn(List.of(p));

        mockMvc.perform(get("/api/v1/products"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.size()").value(1))
                .andExpect(jsonPath("$[0].name").value("Laptop"));
    }

    

    @Test
    void getProductById_WhenExists_ShouldReturnProduct() throws Exception {
        UUID id = UUID.randomUUID();
        Product p = new Product();
        p.setId(id);
        p.setName("Monitor");
        p.setPrice(300.0);

        when(service.findById(id)).thenReturn(p);

        mockMvc.perform(get("/api/v1/products/{id}", id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Monitor"));
    }

    @Test
    void getProductById_WhenNotExists_ShouldReturn400() throws Exception {
        UUID id = UUID.randomUUID();
        when(service.findById(id)).thenThrow(new RuntimeException("Producto con ID " + id + " no encontrado."));

        mockMvc.perform(get("/api/v1/products/{id}", id))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.mensaje").value("Producto con ID " + id + " no encontrado."));
    }

    @Test
    void createProduct_ShouldReturn201() throws Exception {
        Product p = new Product();
        p.setId(UUID.randomUUID());
        p.setName("Teclado");
        p.setPrice(80.0);

        when(service.saveProduct(any())).thenReturn(p);

        mockMvc.perform(post("/api/v1/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(p)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Teclado"));
    }


    
    @Test
    void updateProduct_ShouldReturnUpdatedProduct() throws Exception {
        UUID id = UUID.randomUUID();
        Product p = new Product();
        p.setId(id);
        p.setName("Teclado Mecanico");
        p.setPrice(120.0);

        when(service.updateProduct(any(), any())).thenReturn(p);

        mockMvc.perform(put("/api/v1/products/{id}", id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(p)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Teclado Mecanico"));
    }

    @Test
    void deleteProduct_ShouldReturn204() throws Exception {
        UUID id = UUID.randomUUID();
        doNothing().when(service).deleteById(id);

        mockMvc.perform(delete("/api/v1/products/{id}", id))
                .andExpect(status().isNoContent());

        verify(service, times(1)).deleteById(id);
    }
}
