package br.jus.tjpe.datahub.domain.repository;

import br.jus.tjpe.datahub.domain.model.Lote;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface LoteRepository extends JpaRepository<Lote, UUID> {

    List<Lote> findByNucleoId(UUID nucleoId);

    long countByNucleoId(UUID nucleoId);

    boolean existsByIdentificadorAndNucleoId(String identificador, UUID nucleoId);
}
