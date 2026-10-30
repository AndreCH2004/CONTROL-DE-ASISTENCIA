package com.construandina.asistencia.repository;

import com.construandina.asistencia.model.Empleado;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface EmpleadoRepository extends JpaRepository<Empleado, Integer> {

    Optional<Empleado> findByCodigo(String codigo);

    List<Empleado> findByEstadoTrue();
}
