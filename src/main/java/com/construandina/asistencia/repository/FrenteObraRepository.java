package com.construandina.asistencia.repository;

import com.construandina.asistencia.model.FrenteObra;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FrenteObraRepository extends JpaRepository<FrenteObra, Integer> {

    List<FrenteObra> findByEstadoTrueOrderByNombreAsc();
}
