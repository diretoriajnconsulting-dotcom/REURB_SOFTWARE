package br.jus.tjpe.datahub.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Entidade principal: Nucleo REURB.
 * Representa um assentamento informal em processo de regularizacao.
 */
@Entity
@Table(name = "nucleo", schema = "reurb")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Nucleo {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 300)
    private String nome;

    @Column(name = "municipio_id", nullable = false)
    private Integer municipioId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 1)
    @Builder.Default
    private ModalidadeReurb modalidade = ModalidadeReurb.S;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private StatusNucleo status = StatusNucleo.DRAFT;

    @Column(name = "area_m2")
    private Double areaM2;

    @Column(name = "vertices_count")
    private Integer verticesCount;

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "updated_by")
    private UUID updatedBy;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    @OneToMany(mappedBy = "nucleo", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<Lote> lotes = new ArrayList<>();

    /**
     * Transiciona o status do nucleo, validando a maquina de estados.
     * @throws IllegalStateException se a transicao nao for permitida
     */
    public void transitionTo(StatusNucleo novoStatus) {
        if (!this.status.canTransitionTo(novoStatus)) {
            throw new IllegalStateException(
                String.format("Transicao invalida: %s -> %s. Transicoes permitidas: %s",
                    this.status, novoStatus, this.status.getAllowedTransitions())
            );
        }
        this.status = novoStatus;
    }
}
