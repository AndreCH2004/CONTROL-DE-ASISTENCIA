package com.construandina.asistencia.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "frentes_obra")
public class FrenteObra extends Auditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "nombre", nullable = false, length = 80, unique = true)
    private String nombre;

    @Column(name = "distrito", nullable = false, length = 60)
    private String distrito;

    protected FrenteObra() {
        // requerido por JPA
    }

    public FrenteObra(String nombre, String distrito) {
        this.nombre = nombre;
        this.distrito = distrito;
    }

    public Integer getId() {
        return id;
    }

    public String getNombre() {
        return nombre;
    }

    public String getDistrito() {
        return distrito;
    }
}
