package br.jus.tjpe.datahub.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Lote individual dentro de um nucleo REURB.
 * Cada lote possui seu proprio poligono e pode ser associado a um beneficiario.
 */
@Entity
@Table(name = "lote", schema = "reurb")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Lote {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "nucleo_id", nullable = false)
    private Nucleo nucleo;

    @Column(nullable = false, length = 50)
    private String identificador;

    @Column(name = "beneficiario_id")
    private UUID beneficiarioId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private StatusLote status = StatusLote.DRAFT;

    @Column(name = "area_m2")
    private Double areaM2;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;
}
