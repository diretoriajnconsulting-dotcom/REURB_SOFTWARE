package br.jus.tjpe.datahub.api.dto;

import br.jus.tjpe.datahub.domain.model.ModalidadeReurb;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record NucleoRequest(
    @NotBlank(message = "Nome do nucleo e obrigatorio")
    @Size(max = 300, message = "Nome deve ter no maximo 300 caracteres")
    String nome,

    @NotNull(message = "Codigo IBGE do municipio e obrigatorio")
    Integer municipioIbge,

    ModalidadeReurb modalidade
) {
    public NucleoRequest {
        if (modalidade == null) {
            modalidade = ModalidadeReurb.S;
        }
    }
}
