package com.construandina.asistencia.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "empleados")
public class Empleado extends Auditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    /** Código de empleado; es también el contenido del QR del fotocheck. */
    @Column(name = "codigo", nullable = false, length = 10, unique = true)
    private String codigo;

    @Column(name = "nombre", nullable = false, length = 120)
    private String nombre;

    @ManyToOne(optional = false)
    @JoinColumn(name = "id_turno", nullable = false)
    private Turno turno;

    protected Empleado() {
        // requerido por JPA
    }

    public Empleado(String codigo, String nombre, Turno turno) {
        this.codigo = codigo;
        this.nombre = nombre;
        this.turno = turno;
    }

    /** Un empleado puede marcar asistencia solo si su registro está activo. */
    public boolean estaActivo() {
        return isEstado();
    }

    public Integer getId() {
        return id;
    }

    public String getCodigo() {
        return codigo;
    }

    public String getNombre() {
        return nombre;
    }

    public Turno getTurno() {
        return turno;
    }
}
