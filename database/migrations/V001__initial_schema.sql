-- ===========================================================================
-- DATA HUB FUNDIARIO — Schema Inicial
-- NUREF/TJPE — Moradia Legal Pernambuco
-- Versao: V001
-- Data: 2026-04-13
-- Descricao: Cria schemas e tabelas base para o ciclo de vida REURB,
--            camadas geoespaciais, integracoes externas e auditoria.
-- ===========================================================================

-- Habilitar extensoes necessarias
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ===========================================================================
-- SCHEMA: reurb — Dominio principal (nucleos, lotes, beneficiarios, titulos)
-- ===========================================================================
CREATE SCHEMA IF NOT EXISTS reurb;

-- Enum para modalidade REURB
CREATE TYPE reurb.modalidade_reurb AS ENUM ('S', 'E');

-- Enum para status do nucleo (maquina de estados)
CREATE TYPE reurb.status_nucleo AS ENUM (
    'DRAFT',
    'SUBMITTED',
    'VALIDATING',
    'VALIDATED',
    'REGISTERING',
    'REGISTERED',
    'TITLED',
    'REJECTED',
    'CANCELLED'
);

-- Enum para status do lote
CREATE TYPE reurb.status_lote AS ENUM (
    'DRAFT',
    'VALIDATED',
    'REGISTERING',
    'REGISTERED',
    'TITLED'
);

-- Enum para status do candidato a desjudicializacao
CREATE TYPE reurb.status_candidato_desjud AS ENUM (
    'PENDING',
    'ACCEPTED',
    'REJECTED',
    'UNDER_REVIEW',
    'NOTIFIED',
    'INVALIDATED',
    'AUTO_CLOSED'
);

-- Tabela: Municipio (referencia IBGE)
CREATE TABLE reurb.municipio (
    id              SERIAL PRIMARY KEY,
    codigo_ibge     INTEGER NOT NULL UNIQUE,
    nome            VARCHAR(200) NOT NULL,
    uf              CHAR(2) NOT NULL DEFAULT 'PE',
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_municipio_ibge ON reurb.municipio(codigo_ibge);

-- Tabela: Nucleo REURB
CREATE TABLE reurb.nucleo (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome            VARCHAR(300) NOT NULL,
    municipio_id    INTEGER NOT NULL REFERENCES reurb.municipio(id),
    modalidade      reurb.modalidade_reurb NOT NULL DEFAULT 'S',
    status          reurb.status_nucleo NOT NULL DEFAULT 'DRAFT',
    area_m2         DOUBLE PRECISION,
    vertices_count  INTEGER,
    created_by      UUID,
    updated_by      UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_nucleo_nome_municipio UNIQUE (nome, municipio_id)
);

CREATE INDEX idx_nucleo_municipio ON reurb.nucleo(municipio_id);
CREATE INDEX idx_nucleo_status ON reurb.nucleo(status);
CREATE INDEX idx_nucleo_created ON reurb.nucleo(created_at);

-- Tabela: Beneficiario
CREATE TABLE reurb.beneficiario (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cpf_encrypted       BYTEA NOT NULL,
    cpf_hash            VARCHAR(64) NOT NULL,
    nome                VARCHAR(300) NOT NULL,
    renda_familiar      DECIMAL(12, 2),
    composicao_familiar INTEGER,
    telefone            VARCHAR(20),
    email               VARCHAR(200),
    lgpd_consentimento  BOOLEAN NOT NULL DEFAULT FALSE,
    lgpd_consentimento_at TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_beneficiario_cpf UNIQUE (cpf_hash)
);

CREATE INDEX idx_beneficiario_cpf_hash ON reurb.beneficiario(cpf_hash);

-- Tabela: Lote (subdivisao do nucleo)
CREATE TABLE reurb.lote (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nucleo_id       UUID NOT NULL REFERENCES reurb.nucleo(id) ON DELETE CASCADE,
    identificador   VARCHAR(50) NOT NULL,
    beneficiario_id UUID REFERENCES reurb.beneficiario(id),
    status          reurb.status_lote NOT NULL DEFAULT 'DRAFT',
    area_m2         DOUBLE PRECISION,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_lote_identificador_nucleo UNIQUE (identificador, nucleo_id)
);

CREATE INDEX idx_lote_nucleo ON reurb.lote(nucleo_id);
CREATE INDEX idx_lote_beneficiario ON reurb.lote(beneficiario_id);
CREATE INDEX idx_lote_status ON reurb.lote(status);

-- Tabela: Titulo emitido
CREATE TABLE reurb.titulo (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lote_id             UUID NOT NULL REFERENCES reurb.lote(id),
    numero_matricula    VARCHAR(50),
    cartorio_nome       VARCHAR(300),
    cartorio_cns        VARCHAR(20),
    data_emissao        DATE,
    data_entrega        DATE,
    status              VARCHAR(30) NOT NULL DEFAULT 'EMITIDO',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_titulo_lote ON reurb.titulo(lote_id);

-- Tabela: Processo judicial vinculado
CREATE TABLE reurb.processo_judicial (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    npu                 VARCHAR(25) NOT NULL UNIQUE,
    codigo_assunto      INTEGER NOT NULL,
    descricao_assunto   VARCHAR(300),
    vara                VARCHAR(200),
    comarca             VARCHAR(200),
    partes_autor        TEXT,
    partes_reu          TEXT,
    status_pje          VARCHAR(50),
    endereco_original   TEXT,
    endereco_normalizado JSONB,
    coordenadas         GEOMETRY(Point, 4674),
    score_geocodificacao INTEGER,
    fonte_geocodificacao VARCHAR(30),
    data_distribuicao   DATE,
    data_sync           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_processo_npu ON reurb.processo_judicial(npu);
CREATE INDEX idx_processo_assunto ON reurb.processo_judicial(codigo_assunto);
CREATE INDEX idx_processo_status ON reurb.processo_judicial(status_pje);
CREATE INDEX idx_processo_coordenadas ON reurb.processo_judicial USING GIST (coordenadas);
CREATE INDEX idx_processo_sync ON reurb.processo_judicial(data_sync);

-- Tabela: Candidato a desjudicializacao
CREATE TABLE reurb.candidato_desjud (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    processo_id         UUID NOT NULL REFERENCES reurb.processo_judicial(id),
    nucleo_id           UUID NOT NULL REFERENCES reurb.nucleo(id),
    score_total         INTEGER NOT NULL,
    score_geocodificacao INTEGER NOT NULL,
    score_espacial      INTEGER NOT NULL,
    score_tipo_processo INTEGER NOT NULL,
    tipo_match          VARCHAR(30) NOT NULL DEFAULT 'DENTRO',
    status              reurb.status_candidato_desjud NOT NULL DEFAULT 'PENDING',
    operador_decisao_id UUID,
    justificativa       TEXT,
    data_decisao        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_candidato_processo_nucleo UNIQUE (processo_id, nucleo_id)
);

CREATE INDEX idx_candidato_status ON reurb.candidato_desjud(status);
CREATE INDEX idx_candidato_score ON reurb.candidato_desjud(score_total DESC);
CREATE INDEX idx_candidato_nucleo ON reurb.candidato_desjud(nucleo_id);

-- Tabela: Documento tecnico vinculado ao nucleo
CREATE TABLE reurb.documento (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nucleo_id       UUID NOT NULL REFERENCES reurb.nucleo(id) ON DELETE CASCADE,
    tipo            VARCHAR(50) NOT NULL,
    nome_arquivo    VARCHAR(500) NOT NULL,
    storage_key     VARCHAR(500) NOT NULL,
    tamanho_bytes   BIGINT,
    content_type    VARCHAR(100),
    uploaded_by     UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_documento_nucleo ON reurb.documento(nucleo_id);

-- ===========================================================================
-- SCHEMA: geo — Camadas geoespaciais de referencia
-- ===========================================================================
CREATE SCHEMA IF NOT EXISTS geo;

-- Tabela: Perimetro REURB (geometria do nucleo)
CREATE TABLE geo.perimetro_reurb (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nucleo_id       UUID NOT NULL REFERENCES reurb.nucleo(id) ON DELETE CASCADE,
    geom            GEOMETRY(Polygon, 4674) NOT NULL,
    srid_original   INTEGER,
    area_m2         DOUBLE PRECISION GENERATED ALWAYS AS (
        ST_Area(ST_Transform(geom, 31983))
    ) STORED,
    is_valid        BOOLEAN GENERATED ALWAYS AS (ST_IsValid(geom)) STORED,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_perimetro_valid CHECK (ST_IsValid(geom))
);

CREATE INDEX idx_perimetro_geom ON geo.perimetro_reurb USING GIST (geom);
CREATE INDEX idx_perimetro_nucleo ON geo.perimetro_reurb(nucleo_id);

-- Tabela: Geometria do lote
CREATE TABLE geo.lote_geo (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lote_id         UUID NOT NULL REFERENCES reurb.lote(id) ON DELETE CASCADE,
    nucleo_id       UUID NOT NULL REFERENCES reurb.nucleo(id),
    geom            GEOMETRY(Polygon, 4674) NOT NULL,
    area_m2         DOUBLE PRECISION GENERATED ALWAYS AS (
        ST_Area(ST_Transform(geom, 31983))
    ) STORED,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_lote_valid CHECK (ST_IsValid(geom))
);

CREATE INDEX idx_lote_geo_geom ON geo.lote_geo USING GIST (geom);
CREATE INDEX idx_lote_geo_nucleo ON geo.lote_geo(nucleo_id);
CREATE INDEX idx_lote_geo_lote ON geo.lote_geo(lote_id);

-- Tabela: Areas SPU (terras federais da Uniao)
CREATE TABLE geo.area_spu (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo_spu      VARCHAR(50),
    tipo            VARCHAR(100) NOT NULL,
    orgao           VARCHAR(200),
    descricao       TEXT,
    geom            GEOMETRY(MultiPolygon, 4674) NOT NULL,
    data_importacao TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_spu_geom ON geo.area_spu USING GIST (geom);

-- Tabela: Areas de protecao ambiental
CREATE TABLE geo.area_protecao (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome            VARCHAR(300) NOT NULL,
    tipo            VARCHAR(50) NOT NULL,
    restricao       VARCHAR(50) NOT NULL DEFAULT 'WARNING',
    legislacao      VARCHAR(200),
    geom            GEOMETRY(MultiPolygon, 4674) NOT NULL,
    data_importacao TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_protecao_geom ON geo.area_protecao USING GIST (geom);

-- Tabela: Malha municipal (limites IBGE)
CREATE TABLE geo.malha_municipal (
    id              SERIAL PRIMARY KEY,
    codigo_ibge     INTEGER NOT NULL UNIQUE,
    nome            VARCHAR(200) NOT NULL,
    uf              CHAR(2) NOT NULL DEFAULT 'PE',
    geom            GEOMETRY(MultiPolygon, 4674) NOT NULL,
    data_importacao TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_malha_geom ON geo.malha_municipal USING GIST (geom);

-- Tabela: Conflitos geoespaciais detectados
CREATE TABLE geo.conflito_geoespacial (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nucleo_id               UUID NOT NULL REFERENCES reurb.nucleo(id),
    tipo                    VARCHAR(50) NOT NULL,
    entidade_conflitante_id UUID,
    entidade_nome           VARCHAR(300),
    sobreposicao_pct        DOUBLE PRECISION NOT NULL,
    sobreposicao_area_m2    DOUBLE PRECISION,
    severidade              VARCHAR(20) NOT NULL,
    geom_intersecao         GEOMETRY(Polygon, 4674),
    status                  VARCHAR(30) NOT NULL DEFAULT 'ATIVO',
    resolvido_por           UUID,
    justificativa_resolucao TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at             TIMESTAMPTZ
);

CREATE INDEX idx_conflito_nucleo ON geo.conflito_geoespacial(nucleo_id);
CREATE INDEX idx_conflito_severidade ON geo.conflito_geoespacial(severidade);
CREATE INDEX idx_conflito_status ON geo.conflito_geoespacial(status);

-- ===========================================================================
-- SCHEMA: integration — Eventos de integracao com sistemas externos
-- ===========================================================================
CREATE SCHEMA IF NOT EXISTS integration;

-- Tabela: Eventos SAEC/SREI
CREATE TABLE integration.evento_saec (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nucleo_id       UUID REFERENCES reurb.nucleo(id),
    lote_id         UUID REFERENCES reurb.lote(id),
    tipo_evento     VARCHAR(50) NOT NULL,
    direcao         VARCHAR(10) NOT NULL DEFAULT 'OUTBOUND',
    payload         JSONB NOT NULL,
    protocolo_saec  VARCHAR(100),
    status          VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    tentativas      INTEGER NOT NULL DEFAULT 0,
    erro_mensagem   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at    TIMESTAMPTZ
);

CREATE INDEX idx_evento_saec_nucleo ON integration.evento_saec(nucleo_id);
CREATE INDEX idx_evento_saec_status ON integration.evento_saec(status);
CREATE INDEX idx_evento_saec_tipo ON integration.evento_saec(tipo_evento);

-- Tabela: Eventos PJe
CREATE TABLE integration.evento_pje (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    npu             VARCHAR(25) NOT NULL,
    tipo_evento     VARCHAR(50) NOT NULL,
    payload         JSONB NOT NULL,
    status          VARCHAR(30) NOT NULL DEFAULT 'PROCESSED',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_evento_pje_npu ON integration.evento_pje(npu);
CREATE INDEX idx_evento_pje_created ON integration.evento_pje(created_at);

-- Tabela: Selos SICASE
CREATE TABLE integration.selo_sicase (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero_selo     VARCHAR(50) NOT NULL,
    serventia_nome  VARCHAR(300),
    serventia_cns   VARCHAR(20),
    status          VARCHAR(20) NOT NULL DEFAULT 'ATIVO',
    data_emissao    DATE,
    batch_id        UUID,
    imported_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_selo_numero UNIQUE (numero_selo)
);

CREATE INDEX idx_selo_numero ON integration.selo_sicase(numero_selo);
CREATE INDEX idx_selo_status ON integration.selo_sicase(status);
CREATE INDEX idx_selo_batch ON integration.selo_sicase(batch_id);

-- Tabela: Fila de processamento assincrono
CREATE TABLE integration.fila_processamento (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo            VARCHAR(50) NOT NULL,
    referencia_id   UUID NOT NULL,
    payload         JSONB,
    prioridade      INTEGER NOT NULL DEFAULT 5,
    tentativas      INTEGER NOT NULL DEFAULT 0,
    max_tentativas  INTEGER NOT NULL DEFAULT 3,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    erro_mensagem   TEXT,
    proximo_retry   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at    TIMESTAMPTZ
);

CREATE INDEX idx_fila_status ON integration.fila_processamento(status);
CREATE INDEX idx_fila_tipo ON integration.fila_processamento(tipo);
CREATE INDEX idx_fila_proximo ON integration.fila_processamento(proximo_retry) WHERE status = 'PENDING';

-- ===========================================================================
-- SCHEMA: audit — Trilha de auditoria imutavel
-- ===========================================================================
CREATE SCHEMA IF NOT EXISTS audit;

-- Tabela: Log de auditoria (append-only)
CREATE TABLE audit.log_auditoria (
    id              BIGSERIAL PRIMARY KEY,
    usuario_id      UUID,
    usuario_nome    VARCHAR(200),
    acao            VARCHAR(50) NOT NULL,
    entidade_tipo   VARCHAR(50) NOT NULL,
    entidade_id     UUID NOT NULL,
    dados_anteriores JSONB,
    dados_novos     JSONB,
    ip_origem       INET,
    user_agent      VARCHAR(500),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_auditoria_entidade ON audit.log_auditoria(entidade_tipo, entidade_id);
CREATE INDEX idx_auditoria_usuario ON audit.log_auditoria(usuario_id);
CREATE INDEX idx_auditoria_acao ON audit.log_auditoria(acao);
CREATE INDEX idx_auditoria_created ON audit.log_auditoria(created_at);

-- Tabela: Log de integracoes externas
CREATE TABLE audit.log_integracao (
    id              BIGSERIAL PRIMARY KEY,
    servico         VARCHAR(50) NOT NULL,
    endpoint        VARCHAR(500) NOT NULL,
    metodo_http     VARCHAR(10) NOT NULL,
    request_hash    VARCHAR(64),
    response_status INTEGER,
    latencia_ms     INTEGER,
    erro            BOOLEAN NOT NULL DEFAULT FALSE,
    erro_mensagem   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_log_integ_servico ON audit.log_integracao(servico);
CREATE INDEX idx_log_integ_erro ON audit.log_integracao(erro) WHERE erro = TRUE;
CREATE INDEX idx_log_integ_created ON audit.log_integracao(created_at);

-- ===========================================================================
-- Protecao: Revogar UPDATE/DELETE no schema audit (append-only)
-- ===========================================================================
-- Nota: Em producao, criar um role especifico para servicos com apenas INSERT
-- REVOKE UPDATE, DELETE ON audit.log_auditoria FROM datahub;
-- REVOKE UPDATE, DELETE ON audit.log_integracao FROM datahub;

-- ===========================================================================
-- Dados iniciais: Municipios de Pernambuco (principais)
-- ===========================================================================
INSERT INTO reurb.municipio (codigo_ibge, nome, uf) VALUES
    (2611606, 'Recife', 'PE'),
    (2609600, 'Jaboatao dos Guararapes', 'PE'),
    (2611200, 'Paulista', 'PE'),
    (2610707, 'Olinda', 'PE'),
    (2602902, 'Cabo de Santo Agostinho', 'PE'),
    (2603454, 'Camaragibe', 'PE'),
    (2613701, 'Sao Lourenco da Mata', 'PE'),
    (2607901, 'Igarassu', 'PE'),
    (2600054, 'Abreu e Lima', 'PE'),
    (2607208, 'Goiana', 'PE'),
    (2604106, 'Caruaru', 'PE'),
    (2611101, 'Palmares', 'PE'),
    (2606804, 'Garanhuns', 'PE'),
    (2612208, 'Salgueiro', 'PE'),
    (2611903, 'Petrolina', 'PE'),
    (2605202, 'Escada', 'PE'),
    (2614105, 'Serra Talhada', 'PE'),
    (2601052, 'Araripina', 'PE'),
    (2600609, 'Afogados da Ingazeira', 'PE'),
    (2614501, 'Surubim', 'PE')
ON CONFLICT (codigo_ibge) DO NOTHING;

-- ===========================================================================
-- Configuracao do schema de busca padrao
-- ===========================================================================
ALTER DATABASE datahub_fundiario SET search_path TO reurb, geo, integration, audit, public;
