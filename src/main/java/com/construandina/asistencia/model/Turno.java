package com.construandina.asistencia.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Duration;
import java.time.LocalTime;

@Entity
@Table(name = "turnos")
public class Turno extends Auditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "nombre", nullable = false, length = 40, unique = true)
    private String nombre;

    @Column(name = "hora_inicio", nullable = false)
    private LocalTime horaInicio;

    @Column(name = "hora_fin", nullable = false)
    private LocalTime horaFin;

    protected Turno() {
        // requerido por JPA
    }

    public Turno(String nombre, LocalTime horaInicio, LocalTime horaFin) {
        if (!horaFin.isAfter(horaInicio)) {
            throw new IllegalArgumentException("La hora de fin debe ser posterior a la de inicio");
        }
        this.nombre = nombre;
        this.horaInicio = horaInicio;
        this.horaFin = horaFin;
    }

    /**
     * Minutos de tardanza de un ingreso frente al inicio del turno.
     * Si el ingreso es igual o anterior al inicio, la tardanza es cero.
     */
    public int calcularTardanza(LocalTime horaIngreso) {
        if (!horaIngreso.isAfter(horaInicio)) {
            return 0;
        }
        return (int) Duration.between(horaInicio, horaIngreso).toMinutes();
    }

    public Integer getId() {
        return id;
    }

    public String getNombre() {
        return nombre;
    }

    public LocalTime getHoraInicio() {
        return horaInicio;
    }

    public LocalTime getHoraFin() {
        return horaFin;
    }
}
