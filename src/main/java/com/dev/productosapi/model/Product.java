package com.dev.productosapi.model;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.util.UUID;

@Entity
@Getter @Setter
@Table(name= "products")
@NoArgsConstructor
public class Product {

    @Id
    @NotNull(message = "El ID no puede ser nulo")
    private UUID id;

    @NotBlank(message = "El nombre del producto no puede estar vacío")
    private String name;

    @NotNull(message = "El precio es obligatorio y no puede ser nulo")
    @Positive(message = "El precio debe ser mayor a cero")
    private Double price;
}