package com.construandina.asistencia.controller;

import com.construandina.asistencia.model.Empleado;
import com.construandina.asistencia.model.FrenteObra;
import com.construandina.asistencia.model.Turno;
import com.construandina.asistencia.repository.EmpleadoRepository;
import com.construandina.asistencia.repository.FrenteObraRepository;
import com.construandina.asistencia.repository.TurnoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class AsistenciaControllerTest {

    @Autowired private MockMvc mvc;
    @Autowired private TurnoRepository turnos;
    @Autowired private FrenteObraRepository frentes;
    @Autowired private EmpleadoRepository empleados;

    private Integer idFrente;

    @BeforeEach
    void datos() {
        Turno t = new Turno("Turno controller", LocalTime.of(7, 0), LocalTime.of(16, 0));
        t.setIdUsuario(1);
        turnos.save(t);

        FrenteObra f = new FrenteObra("Obra Surco", "Santiago de Surco");
        f.setIdUsuario(1);
        frentes.save(f);
        idFrente = f.getId();

        Empleado e = new Empleado("EMP-101", "Luis Huamán Quispe", t);
        e.setIdUsuario(1);
        empleados.save(e);
    }

    @Test
    void marcajeConCodigoValidoDevuelveOk() throws Exception {
        mvc.perform(post("/api/asistencia/marcajes")
                        .contentType("application/json")
                        .content("{\"codigo\":\"EMP-101\",\"idFrenteObra\":" + idFrente + "}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.codigoEmpleado").value("EMP-101"));
    }

    @Test
    void salidaSinEntradaDevuelveMensaje() throws Exception {
        mvc.perform(post("/api/asistencia/salida")
                        .contentType("application/json")
                        .content("{\"codigo\":\"EMP-101\"}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.mensaje").value("Primero debe registrar la entrada de hoy"));
    }

    @Test
    void entradaConCodigoValidoDevuelveOk() throws Exception {
        mvc.perform(post("/api/asistencia/entrada")
                        .contentType("application/json")
                        .content("{\"codigo\":\"EMP-101\",\"idFrenteObra\":" + idFrente + "}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.horaSalida").doesNotExist());
    }

    @Test
    void codigoInexistenteDevuelveNotFoundConMensaje() throws Exception {
        mvc.perform(post("/api/asistencia/marcajes")
                        .contentType("application/json")
                        .content("{\"codigo\":\"EMP-999\",\"idFrenteObra\":" + idFrente + "}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.mensaje").value("Código no registrado"));
    }

    @Test
    void datosIncompletosDevuelvenBadRequest() throws Exception {
        mvc.perform(post("/api/asistencia/marcajes")
                        .contentType("application/json")
                        .content("{\"codigo\":\"\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void indiceDeLaApiResponde() throws Exception {
        mvc.perform(get("/api"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.estado").value("UP"));
    }

    @Test
    void vistaWebSeSirveEnLaRaiz() throws Exception {
        mvc.perform(get("/index.html"))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Control de Asistencia")));
    }

    @Test
    void listaFrentesActivos() throws Exception {
        mvc.perform(get("/api/frentes"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.nombre == 'Obra Surco')].id").value(idFrente));
    }

    @Test
    void rutaInexistenteDevuelveNotFound() throws Exception {
        mvc.perform(get("/no-existe"))
                .andExpect(status().isNotFound());
    }

    @Test
    void saludDelServicioResponde() throws Exception {
        mvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.estado").value("UP"));
    }
}
