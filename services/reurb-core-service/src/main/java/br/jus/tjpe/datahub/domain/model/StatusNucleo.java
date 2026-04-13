package br.jus.tjpe.datahub.domain.model;

import java.util.Set;

/**
 * Maquina de estados do nucleo REURB.
 * Define todas as transicoes permitidas entre estados.
 */
public enum StatusNucleo {
    DRAFT(Set.of("SUBMITTED", "CANCELLED")),
    SUBMITTED(Set.of("VALIDATING", "CANCELLED")),
    VALIDATING(Set.of("VALIDATED", "DRAFT")),
    VALIDATED(Set.of("REGISTERING", "DRAFT")),
    REGISTERING(Set.of("REGISTERED", "VALIDATED")),
    REGISTERED(Set.of("TITLED")),
    TITLED(Set.of()),
    REJECTED(Set.of("DRAFT")),
    CANCELLED(Set.of());

    private final Set<String> allowedTransitions;

    StatusNucleo(Set<String> allowedTransitions) {
        this.allowedTransitions = allowedTransitions;
    }

    public boolean canTransitionTo(StatusNucleo target) {
        return allowedTransitions.contains(target.name());
    }

    public Set<String> getAllowedTransitions() {
        return allowedTransitions;
    }
}
