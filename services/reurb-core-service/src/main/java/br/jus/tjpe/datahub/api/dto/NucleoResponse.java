package br.jus.tjpe.datahub.api.dto;

import br.jus.tjpe.datahub.domain.model.ModalidadeReurb;
import br.jus.tjpe.datahub.domain.model.StatusNucleo;

import java.time.OffsetDateTime;
import java.util.UUID;

public record NucleoResponse(
    UUID id,
    String nome,
    Integer municipioId,
    String municipioNome,
    ModalidadeReurb modalidade,
    StatusNucleo status,
    Double areaM2,
    Integer verticesCount,
    long lotesCount,
    OffsetDateTime createdAt,
    OffsetDateTime updatedAt
) {}
