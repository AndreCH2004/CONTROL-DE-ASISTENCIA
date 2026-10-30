package com.construandina.asistencia.service;

import com.construandina.asistencia.exception.NegocioException;
import com.construandina.asistencia.model.Empleado;
import com.construandina.asistencia.model.FrenteObra;
import com.construandina.asistencia.model.RegistroAsistencia;
import com.construandina.asistencia.model.Turno;
import com.construandina.asistencia.repository.EmpleadoRepository;
import com.construandina.asistencia.repository.FrenteObraRepository;
import com.construandina.asistencia.repository.RegistroAsistenciaRepository;
import com.construandina.asistencia.repository.TurnoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@Transactional
class AsistenciaServiceTest {

    private static final LocalDate FECHA = LocalDate.of(2026, 10, 30);

    @Autowired private AsistenciaService servicio;
    @Autowired private TurnoRepository turnos;
    @Autowired private FrenteObraRepository frentes;
    @Autowired private EmpleadoRepository empleados;
    @Autowired private RegistroAsistenciaRepository registros;

    private FrenteObra frente;
    private Empleado juan;
    private Empleado maria;

    @BeforeEach
    void datosDePrueba() {
        Turno diurno = new Turno("Turno diurno", LocalTime.of(7, 0), LocalTime.of(16, 0));
        diurno.setIdUsuario(1);
        turnos.save(diurno);

        frente = new FrenteObra("Obra San Isidro", "San Isidro");
        frente.setIdUsuario(1);
        frentes.save(frente);

        juan = new Empleado("EMP-001", "Juan Ramírez Soto", diurno);
        juan.setIdUsuario(1);
        empleados.save(juan);

        maria = new Empleado("EMP-002", "María Castro Díaz", diurno);
        maria.setIdUsuario(1);
        empleados.save(maria);
    }

    private LocalDateTime a(int hora, int minuto) {
        return FECHA.atTime(hora, minuto);
    }

    @Test
    void primerMarcajeRegistraIngresoConTardanza() {
        RegistroAsistencia r = servicio.registrarMarcaje("EMP-001", frente.getId(), a(7, 20));

        assertThat(r.getHoraIngreso()).isEqualTo(LocalTime.of(7, 20));
        assertThat(r.getMinutosTardanza()).isEqualTo(20);
        assertThat(r.getHorasTrabajadas()).isEqualByComparingTo(BigDecimal.ZERO);
        assertThat(r.isEsFalta()).isFalse();
    }

    @Test
    void ingresoPuntualNoGeneraTardanza() {
        RegistroAsistencia r = servicio.registrarMarcaje("EMP-002", frente.getId(), a(6, 50));

        assertThat(r.getMinutosTardanza()).isZero();
    }

    @Test
    void segundoMarcajeRegistraSalidaYHorasTrabajadas() {
        servicio.registrarMarcaje("EMP-001", frente.getId(), a(7, 20));

        RegistroAsistencia r = servicio.registrarMarcaje("EMP-001", frente.getId(), a(16, 0));

        assertThat(r.getHoraSalida()).isEqualTo(LocalTime.of(16, 0));
        assertThat(r.getHorasTrabajadas()).isEqualByComparingTo(new BigDecimal("8.67"));
    }

    @Test
    void tercerMarcajeDelDiaEsRechazado() {
        servicio.registrarMarcaje("EMP-001", frente.getId(), a(7, 0));
        servicio.registrarMarcaje("EMP-001", frente.getId(), a(16, 0));

        assertThatThrownBy(() -> servicio.registrarMarcaje("EMP-001", frente.getId(), a(17, 0)))
                .isInstanceOf(NegocioException.class)
                .extracting("status").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void codigoInexistenteEsRechazado() {
        assertThatThrownBy(() -> servicio.registrarMarcaje("EMP-999", frente.getId(), a(7, 0)))
                .isInstanceOf(NegocioException.class)
                .extracting("status").isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void empleadoInactivoEsRechazado() {
        juan.setEstado(false);
        empleados.save(juan);

        assertThatThrownBy(() -> servicio.registrarMarcaje("EMP-001", frente.getId(), a(7, 0)))
                .isInstanceOf(NegocioException.class)
                .extracting("status").isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY);
    }

    @Test
    void salidaAnteriorALaEntradaEsRechazada() {
        servicio.registrarMarcaje("EMP-001", frente.getId(), a(7, 0));

        assertThatThrownBy(() -> servicio.registrarMarcaje("EMP-001", frente.getId(), a(6, 30)))
                .isInstanceOf(NegocioException.class)
                .extracting("status").isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY);
    }

    @Test
    void entradaYSalidaExplicitasCalculanHoras() {
        servicio.registrarEntrada("EMP-001", frente.getId(), a(7, 0));

        RegistroAsistencia r = servicio.registrarSalida(" emp-001 ", a(15, 30));

        assertThat(r.getHorasTrabajadas()).isEqualByComparingTo(new BigDecimal("8.50"));
    }

    @Test
    void segundaEntradaDelDiaEsRechazada() {
        servicio.registrarEntrada("EMP-001", frente.getId(), a(7, 0));

        assertThatThrownBy(() -> servicio.registrarEntrada("EMP-001", frente.getId(), a(7, 5)))
                .isInstanceOf(NegocioException.class)
                .extracting("status").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void salidaSinEntradaEsRechazada() {
        assertThatThrownBy(() -> servicio.registrarSalida("EMP-001", a(16, 0)))
                .isInstanceOf(NegocioException.class)
                .hasMessage("Primero debe registrar la entrada de hoy")
                .extracting("status").isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY);
    }

    @Test
    void salidaDeUnDiaConFaltaEsRechazada() {
        servicio.marcarFaltas(FECHA, frente.getId());

        assertThatThrownBy(() -> servicio.registrarSalida("EMP-001", a(16, 0)))
                .isInstanceOf(NegocioException.class)
                .extracting("status").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void cierreMarcaFaltasSoloAQuienNoMarco() {
        servicio.registrarMarcaje("EMP-001", frente.getId(), a(7, 0));

        int faltas = servicio.marcarFaltas(FECHA, frente.getId());

        assertThat(faltas).isEqualTo(1);
        RegistroAsistencia falta = registros
                .findByEmpleadoIdAndFechaRegistro(maria.getId(), FECHA).orElseThrow();
        assertThat(falta.isEsFalta()).isTrue();
        assertThat(falta.getHoraIngreso()).isNull();
        assertThat(falta.getHorasTrabajadas()).isEqualByComparingTo(BigDecimal.ZERO);
    }

    @Test
    void reporteIncluyeSoloLosRegistrosDelFrenteYDelPeriodo() {
        servicio.registrarMarcaje("EMP-001", frente.getId(), a(7, 0));

        var reporte = servicio.generarReporte(frente.getId(), FECHA, FECHA);

        assertThat(reporte).hasSize(1);
        assertThat(reporte.get(0).getEmpleado().getCodigo()).isEqualTo("EMP-001");
    }

    @Test
    void reporteConFechasInvertidasEsRechazado() {
        assertThatThrownBy(() -> servicio.generarReporte(frente.getId(), FECHA, FECHA.minusDays(1)))
                .isInstanceOf(NegocioException.class);
    }
}
