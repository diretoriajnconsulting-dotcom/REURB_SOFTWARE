package br.jus.tjpe.datahub.domain.repository;

import br.jus.tjpe.datahub.domain.model.Nucleo;
import br.jus.tjpe.datahub.domain.model.StatusNucleo;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface NucleoRepository extends JpaRepository<Nucleo, UUID> {

    Page<Nucleo> findByMunicipioId(Integer municipioId, Pageable pageable);

    Page<Nucleo> findByStatus(StatusNucleo status, Pageable pageable);

    Page<Nucleo> findByMunicipioIdAndStatus(Integer municipioId, StatusNucleo status, Pageable pageable);

    Optional<Nucleo> findByNomeAndMunicipioId(String nome, Integer municipioId);

    @Query("SELECT COUNT(n) FROM Nucleo n WHERE n.municipioId = :municipioId AND n.status = :status")
    long countByMunicipioAndStatus(@Param("municipioId") Integer municipioId,
                                    @Param("status") StatusNucleo status);

    @Query("SELECT n.status, COUNT(n) FROM Nucleo n WHERE n.municipioId = :municipioId GROUP BY n.status")
    java.util.List<Object[]> countByMunicipioGroupByStatus(@Param("municipioId") Integer municipioId);
}
