package br.jus.tjpe.datahub.domain.service;

import br.jus.tjpe.datahub.api.dto.NucleoRequest;
import br.jus.tjpe.datahub.api.dto.NucleoResponse;
import br.jus.tjpe.datahub.api.dto.StatusTransitionRequest;
import br.jus.tjpe.datahub.domain.model.Nucleo;
import br.jus.tjpe.datahub.domain.model.StatusNucleo;
import br.jus.tjpe.datahub.domain.repository.LoteRepository;
import br.jus.tjpe.datahub.domain.repository.NucleoRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class NucleoService {

    private final NucleoRepository nucleoRepository;
    private final LoteRepository loteRepository;
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Transactional
    public NucleoResponse criar(NucleoRequest request) {
        nucleoRepository.findByNomeAndMunicipioId(request.nome(), request.municipioIbge())
            .ifPresent(existing -> {
                throw new IllegalArgumentException(
                    "Ja existe um nucleo com nome '" + request.nome() +
                    "' no municipio " + request.municipioIbge()
                );
            });

        var nucleo = Nucleo.builder()
            .nome(request.nome())
            .municipioId(request.municipioIbge())
            .modalidade(request.modalidade())
            .status(StatusNucleo.DRAFT)
            .build();

        nucleo = nucleoRepository.save(nucleo);
        log.info("Nucleo criado: id={}, nome={}, municipio={}",
            nucleo.getId(), nucleo.getNome(), nucleo.getMunicipioId());

        return toResponse(nucleo);
    }

    @Transactional(readOnly = true)
    public NucleoResponse buscarPorId(UUID id) {
        var nucleo = nucleoRepository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("Nucleo nao encontrado: " + id));
        return toResponse(nucleo);
    }

    @Transactional(readOnly = true)
    public Page<NucleoResponse> listar(Integer municipioId, StatusNucleo status, Pageable pageable) {
        Page<Nucleo> nucleos;

        if (municipioId != null && status != null) {
            nucleos = nucleoRepository.findByMunicipioIdAndStatus(municipioId, status, pageable);
        } else if (municipioId != null) {
            nucleos = nucleoRepository.findByMunicipioId(municipioId, pageable);
        } else if (status != null) {
            nucleos = nucleoRepository.findByStatus(status, pageable);
        } else {
            nucleos = nucleoRepository.findAll(pageable);
        }

        return nucleos.map(this::toResponse);
    }

    @Transactional
    public NucleoResponse transicionarStatus(UUID id, StatusTransitionRequest request) {
        var nucleo = nucleoRepository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("Nucleo nao encontrado: " + id));

        var statusAnterior = nucleo.getStatus();
        nucleo.transitionTo(request.novoStatus());
        nucleo = nucleoRepository.save(nucleo);

        log.info("Nucleo transicionado: id={}, {} -> {}", id, statusAnterior, request.novoStatus());

        kafkaTemplate.send("reurb.nucleo.status_changed", id.toString(), Map.of(
            "nucleoId", id.toString(),
            "statusAnterior", statusAnterior.name(),
            "statusNovo", request.novoStatus().name(),
            "justificativa", request.justificativa() != null ? request.justificativa() : "",
            "timestamp", java.time.OffsetDateTime.now().toString()
        ));

        return toResponse(nucleo);
    }

    private NucleoResponse toResponse(Nucleo nucleo) {
        long lotesCount = loteRepository.countByNucleoId(nucleo.getId());
        return new NucleoResponse(
            nucleo.getId(),
            nucleo.getNome(),
            nucleo.getMunicipioId(),
            null,
            nucleo.getModalidade(),
            nucleo.getStatus(),
            nucleo.getAreaM2(),
            nucleo.getVerticesCount(),
            lotesCount,
            nucleo.getCreatedAt(),
            nucleo.getUpdatedAt()
        );
    }
}
