package br.jus.tjpe.datahub.domain.repository;

import br.jus.tjpe.datahub.domain.model.Beneficiario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface BeneficiarioRepository extends JpaRepository<Beneficiario, UUID> {

    Optional<Beneficiario> findByCpfHash(String cpfHash);

    boolean existsByCpfHash(String cpfHash);
}
