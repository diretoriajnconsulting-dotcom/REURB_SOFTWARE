package br.jus.tjpe.datahub.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Beneficiario da regularizacao fundiaria.
 * CPF armazenado criptografado (AES-256-GCM) para conformidade LGPD.
 */
@Entity
@Table(name = "beneficiario", schema = "reurb")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Beneficiario {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "cpf_encrypted", nullable = false)
    private byte[] cpfEncrypted;

    @Column(name = "cpf_hash", nullable = false, unique = true, length = 64)
    private String cpfHash;

    @Column(nullable = false, length = 300)
    private String nome;

    @Column(name = "renda_familiar")
    private BigDecimal rendaFamiliar;

    @Column(name = "composicao_familiar")
    private Integer composicaoFamiliar;

    @Column(length = 20)
    private String telefone;

    @Column(length = 200)
    private String email;

    @Column(name = "lgpd_consentimento", nullable = false)
    @Builder.Default
    private Boolean lgpdConsentimento = false;

    @Column(name = "lgpd_consentimento_at")
    private OffsetDateTime lgpdConsentimentoAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;
}
