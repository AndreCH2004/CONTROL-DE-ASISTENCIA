package com.construandina.asistencia.repository;

import com.construandina.asistencia.model.RegistroAsistencia;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface RegistroAsistenciaRepository extends JpaRepository<RegistroAsistencia, Integer> {

    Optional<RegistroAsistencia> findByEmpleadoIdAndFechaRegistro(Integer idEmpleado, LocalDate fecha);

    List<RegistroAsistencia> findByFrenteObraIdAndFechaRegistroBetweenOrderByFechaRegistroAscIdAsc(
            Integer idFrente, LocalDate inicio, LocalDate fin);
}
