package com.construandina.asistencia.model;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.PreUpdate;

import java.time.LocalDateTime;

/**
 * Campos de auditoría comunes a las tablas de operación.
 * creado_el lo asigna la base de datos (DEFAULT SYSDATETIME()).
 */
@MappedSuperclass
public abstract class Auditable {

    @Column(name = "creado_el", insertable = false, updatable = false)
    private LocalDateTime creadoEl;

    @Column(name = "actualizado_el")
    private LocalDateTime actualizadoEl;

    @Column(name = "id_usuario", nullable = false)
    private Integer idUsuario;

    @Column(name = "estado", nullable = false)
    private boolean estado = true;

    @PreUpdate
    void marcarActualizacion() {
        this.actualizadoEl = LocalDateTime.now();
    }

    public LocalDateTime getCreadoEl() {
        return creadoEl;
    }

    public LocalDateTime getActualizadoEl() {
        return actualizadoEl;
    }

    public Integer getIdUsuario() {
        return idUsuario;
    }

    public void setIdUsuario(Integer idUsuario) {
        this.idUsuario = idUsuario;
    }

    public boolean isEstado() {
        return estado;
    }

    public void setEstado(boolean estado) {
        this.estado = estado;
    }
}
