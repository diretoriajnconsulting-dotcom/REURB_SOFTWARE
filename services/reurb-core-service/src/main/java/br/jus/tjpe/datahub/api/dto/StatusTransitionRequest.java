package br.jus.tjpe.datahub.api.dto;

import br.jus.tjpe.datahub.domain.model.StatusNucleo;
import jakarta.validation.constraints.NotNull;

public record StatusTransitionRequest(
    @NotNull(message = "Novo status e obrigatorio")
    StatusNucleo novoStatus,

    String justificativa
) {}
