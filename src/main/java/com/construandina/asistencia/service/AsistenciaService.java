package com.construandina.asistencia.service;

import com.construandina.asistencia.exception.NegocioException;
import com.construandina.asistencia.model.Empleado;
import com.construandina.asistencia.model.FrenteObra;
import com.construandina.asistencia.model.RegistroAsistencia;
import com.construandina.asistencia.repository.EmpleadoRepository;
import com.construandina.asistencia.repository.FrenteObraRepository;
import com.construandina.asistencia.repository.RegistroAsistenciaRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.List;

/** Reglas de negocio del control de asistencia. */
@Service
public class AsistenciaService {

    private final EmpleadoRepository empleados;
    private final FrenteObraRepository frentes;
    private final RegistroAsistenciaRepository registros;
    private final Integer idUsuarioAuditoria;

    public AsistenciaService(EmpleadoRepository empleados,
                             FrenteObraRepository frentes,
                             RegistroAsistenciaRepository registros,
                             @Value("${app.usuario-auditoria-id}") Integer idUsuarioAuditoria) {
        this.empleados = empleados;
        this.frentes = frentes;
        this.registros = registros;
        this.idUsuarioAuditoria = idUsuarioAuditoria;
    }

    /** Valida que el código exista y que el empleado esté activo. */
    @Transactional(readOnly = true)
    public Empleado validarCodigo(String codigo) {
        Empleado empleado = empleados.findByCodigo(codigo.trim().toUpperCase())
                .orElseThrow(() -> new NegocioException(HttpStatus.NOT_FOUND, "Código no registrado"));
        if (!empleado.estaActivo()) {
            throw new NegocioException(HttpStatus.UNPROCESSABLE_ENTITY, "El empleado no está activo");
        }
        return empleado;
    }

    /**
     * Procesa un marcaje sin indicar el tipo. El primer marcaje del día registra la entrada
     * y la tardanza; el segundo registra la salida y las horas trabajadas.
     */
    @Transactional
    public RegistroAsistencia registrarMarcaje(String codigo, Integer idFrente, LocalDateTime momento) {
        Empleado empleado = validarCodigo(codigo);
        boolean tieneEntrada = registros
                .findByEmpleadoIdAndFechaRegistro(empleado.getId(), momento.toLocalDate())
                .isPresent();
        return tieneEntrada
                ? registrarSalida(codigo, momento)
                : registrarEntrada(codigo, idFrente, momento);
    }

    /** Registra la entrada del día en el frente indicado y calcula la tardanza. */
    @Transactional
    public RegistroAsistencia registrarEntrada(String codigo, Integer idFrente, LocalDateTime momento) {
        Empleado empleado = validarCodigo(codigo);
        FrenteObra frente = frentes.findById(idFrente)
                .orElseThrow(() -> new NegocioException(HttpStatus.NOT_FOUND, "Frente de obra no encontrado"));
        LocalDate fecha = momento.toLocalDate();

        registros.findByEmpleadoIdAndFechaRegistro(empleado.getId(), fecha).ifPresent(r -> {
            throw new NegocioException(HttpStatus.CONFLICT, r.isEsFalta()
                    ? "El día ya fue registrado como falta"
                    : "La entrada de hoy ya fue registrada a las " + r.getHoraIngreso());
        });

        RegistroAsistencia registro = new RegistroAsistencia(empleado, frente, fecha);
        registro.setIdUsuario(idUsuarioAuditoria);
        registro.registrarIngreso(hora(momento));
        return registros.save(registro);
    }

    /** Registra la salida del día (cierre del empleado) y calcula las horas trabajadas. */
    @Transactional
    public RegistroAsistencia registrarSalida(String codigo, LocalDateTime momento) {
        Empleado empleado = validarCodigo(codigo);
        RegistroAsistencia registro = registros
                .findByEmpleadoIdAndFechaRegistro(empleado.getId(), momento.toLocalDate())
                .orElseThrow(() -> new NegocioException(HttpStatus.UNPROCESSABLE_ENTITY,
                        "Primero debe registrar la entrada de hoy"));

        if (registro.isEsFalta()) {
            throw new NegocioException(HttpStatus.CONFLICT, "El día ya fue registrado como falta");
        }
        if (registro.tieneSalida()) {
            throw new NegocioException(HttpStatus.CONFLICT,
                    "La salida de hoy ya fue registrada a las " + registro.getHoraSalida());
        }
        try {
            registro.registrarSalida(hora(momento));
        } catch (IllegalArgumentException ex) {
            throw new NegocioException(HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage());
        }
        return registros.save(registro);
    }

    private static LocalTime hora(LocalDateTime momento) {
        return momento.toLocalTime().truncatedTo(ChronoUnit.SECONDS);
    }

    /**
     * Cierre del día: marca como falta a cada empleado activo sin ningún marcaje en la fecha.
     * La falta se registra en el frente indicado, porque el sistema aún no asigna un frente a cada empleado.
     */
    @Transactional
    public int marcarFaltas(LocalDate fecha, Integer idFrente) {
        FrenteObra frente = frentes.findById(idFrente)
                .orElseThrow(() -> new NegocioException(HttpStatus.NOT_FOUND, "Frente de obra no encontrado"));
        int marcadas = 0;
        for (Empleado empleado : empleados.findByEstadoTrue()) {
            if (registros.findByEmpleadoIdAndFechaRegistro(empleado.getId(), fecha).isEmpty()) {
                RegistroAsistencia falta = new RegistroAsistencia(empleado, frente, fecha);
                falta.setIdUsuario(idUsuarioAuditoria);
                falta.marcarFalta();
                registros.save(falta);
                marcadas++;
            }
        }
        return marcadas;
    }

    @Transactional(readOnly = true)
    public List<RegistroAsistencia> generarReporte(Integer idFrente, LocalDate inicio, LocalDate fin) {
        if (fin.isBefore(inicio)) {
            throw new NegocioException(HttpStatus.UNPROCESSABLE_ENTITY, "La fecha final es anterior a la inicial");
        }
        return registros.findByFrenteObraIdAndFechaRegistroBetweenOrderByFechaRegistroAscIdAsc(idFrente, inicio, fin);
    }
}
