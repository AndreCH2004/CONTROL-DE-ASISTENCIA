package com.construandina.asistencia.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;

/** Marcaje diario de un empleado en un frente de obra (un registro por empleado y día). */
@Entity
@Table(name = "registros_asistencia",
        uniqueConstraints = @UniqueConstraint(name = "uq_registros_asistencia_empleado_fecha",
                columnNames = {"id_empleado", "fecha_registro"}))
public class RegistroAsistencia extends Auditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "id_empleado", nullable = false)
    private Empleado empleado;

    @ManyToOne(optional = false)
    @JoinColumn(name = "id_frente_obra", nullable = false)
    private FrenteObra frenteObra;

    @Column(name = "fecha_registro", nullable = false)
    private LocalDate fechaRegistro;

    @Column(name = "hora_ingreso")
    private LocalTime horaIngreso;

    @Column(name = "hora_salida")
    private LocalTime horaSalida;

    @Column(name = "horas_trabajadas", nullable = false, precision = 5, scale = 2)
    private BigDecimal horasTrabajadas = BigDecimal.ZERO;

    @Column(name = "minutos_tardanza", nullable = false)
    private int minutosTardanza;

    @Column(name = "es_falta", nullable = false)
    private boolean esFalta;

    protected RegistroAsistencia() {
        // requerido por JPA
    }

    public RegistroAsistencia(Empleado empleado, FrenteObra frenteObra, LocalDate fecha) {
        this.empleado = empleado;
        this.frenteObra = frenteObra;
        this.fechaRegistro = fecha;
    }

    /** Registra la entrada del día y calcula la tardanza frente al turno del empleado. */
    public void registrarIngreso(LocalTime hora) {
        if (horaIngreso != null) {
            throw new IllegalStateException("La entrada del día ya fue registrada");
        }
        this.horaIngreso = hora;
        this.minutosTardanza = empleado.getTurno().calcularTardanza(hora);
        this.esFalta = false;
    }

    /** Registra la salida y calcula las horas trabajadas con dos decimales. */
    public void registrarSalida(LocalTime hora) {
        if (horaIngreso == null) {
            throw new IllegalStateException("Primero debe registrarse la entrada");
        }
        if (horaSalida != null) {
            throw new IllegalStateException("La salida del día ya fue registrada");
        }
        if (!hora.isAfter(horaIngreso)) {
            throw new IllegalArgumentException("La salida debe ser posterior a la entrada");
        }
        this.horaSalida = hora;
        long minutos = Duration.between(horaIngreso, hora).toMinutes();
        this.horasTrabajadas = BigDecimal.valueOf(minutos)
                .divide(BigDecimal.valueOf(60), 2, RoundingMode.HALF_UP);
    }

    /** Marca el día como falta: sin entrada, sin tardanza y sin horas. */
    public void marcarFalta() {
        this.esFalta = true;
        this.horaIngreso = null;
        this.horaSalida = null;
        this.horasTrabajadas = BigDecimal.ZERO;
        this.minutosTardanza = 0;
    }

    public boolean tieneSalida() {
        return horaSalida != null;
    }

    public Integer getId() {
        return id;
    }

    public Empleado getEmpleado() {
        return empleado;
    }

    public FrenteObra getFrenteObra() {
        return frenteObra;
    }

    public LocalDate getFechaRegistro() {
        return fechaRegistro;
    }

    public LocalTime getHoraIngreso() {
        return horaIngreso;
    }

    public LocalTime getHoraSalida() {
        return horaSalida;
    }

    public BigDecimal getHorasTrabajadas() {
        return horasTrabajadas;
    }

    public int getMinutosTardanza() {
        return minutosTardanza;
    }

    public boolean isEsFalta() {
        return esFalta;
    }
}
