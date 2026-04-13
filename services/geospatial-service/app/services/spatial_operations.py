"""
Operacoes espaciais centrais do Data Hub Fundiario.
Usa PostGIS para validacao de geometria, deteccao de conflitos
e transformacoes de coordenadas SIRGAS2000.
"""

import time
import logging
from typing import List, Optional, Tuple
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.schemas import (
    ConflitoDetectado,
    ConflictCheckResponse,
    SeveridadeConflito,
    TipoConflito,
    ValidacaoErro,
    ValidacaoResponse,
)

logger = logging.getLogger(__name__)


async def validar_geometria(db: AsyncSession, geojson: dict) -> ValidacaoResponse:
    """
    Valida um poligono GeoJSON:
    - Verifica fechamento (ST_IsClosed)
    - Verifica auto-intersecao (ST_IsValid)
    - Calcula area em m2 (UTM 23S)
    - Verifica area minima
    """
    geojson_str = str(geojson).replace("'", '"')

    query = text("""
        WITH input_geom AS (
            SELECT ST_SetSRID(ST_GeomFromGeoJSON(:geojson), :srid) AS geom
        )
        SELECT
            ST_IsValid(geom) AS is_valid,
            ST_IsValidReason(geom) AS valid_reason,
            ST_Area(ST_Transform(geom, :utm_srid)) AS area_m2,
            ST_SRID(geom) AS srid,
            ST_X(ST_Centroid(geom)) AS centroid_lng,
            ST_Y(ST_Centroid(geom)) AS centroid_lat,
            ST_NPoints(geom) AS vertices_count
        FROM input_geom
    """)

    result = await db.execute(query, {
        "geojson": geojson_str,
        "srid": settings.SIRGAS2000_SRID,
        "utm_srid": settings.UTM_23S_SRID,
    })
    row = result.fetchone()

    errors = []

    if not row.is_valid:
        errors.append(ValidacaoErro(
            tipo="GEOMETRIA_INVALIDA",
            mensagem=f"Geometria invalida: {row.valid_reason}",
        ))

    if row.area_m2 and row.area_m2 < settings.MIN_AREA_M2:
        errors.append(ValidacaoErro(
            tipo="AREA_INSUFICIENTE",
            mensagem=f"Area de {row.area_m2:.1f}m2 e menor que o minimo de {settings.MIN_AREA_M2}m2",
        ))

    return ValidacaoResponse(
        is_valid=len(errors) == 0,
        errors=errors,
        area_m2=row.area_m2,
        srid_detectado=row.srid,
        centroide=[row.centroid_lat, row.centroid_lng] if row.centroid_lat else None,
    )


async def verificar_conflitos(
    db: AsyncSession,
    nucleo_id: UUID,
    geojson: dict
) -> ConflictCheckResponse:
    """
    Executa verificacao de conflitos espaciais contra todas as camadas de referencia.
    Retorna lista de conflitos classificados por severidade.
    """
    start_time = time.time()
    geojson_str = str(geojson).replace("'", '"')
    conflitos: List[ConflitoDetectado] = []

    # Check 1: Outros nucleos REURB
    query_nucleos = text("""
        WITH target AS (
            SELECT ST_SetSRID(ST_GeomFromGeoJSON(:geojson), :srid) AS geom
        )
        SELECT
            n.id::text AS nucleo_id,
            n.nome AS nucleo_nome,
            ST_Area(ST_Intersection(p.geom, t.geom)) / ST_Area(t.geom) * 100 AS pct,
            ST_Area(ST_Transform(ST_Intersection(p.geom, t.geom), :utm_srid)) AS area_m2,
            ST_AsGeoJSON(ST_Intersection(p.geom, t.geom)) AS geom_intersecao
        FROM geo.perimetro_reurb p
        JOIN reurb.nucleo n ON p.nucleo_id = n.id
        CROSS JOIN target t
        WHERE ST_Intersects(p.geom, t.geom)
        AND n.id != :nucleo_id
        AND n.status NOT IN ('DRAFT', 'REJECTED', 'CANCELLED')
        AND ST_Area(ST_Intersection(p.geom, t.geom)) > 1
    """)

    result = await db.execute(query_nucleos, {
        "geojson": geojson_str,
        "srid": settings.SIRGAS2000_SRID,
        "utm_srid": settings.UTM_23S_SRID,
        "nucleo_id": str(nucleo_id),
    })

    for row in result.fetchall():
        severidade = (SeveridadeConflito.BLOCKING
                      if row.pct > settings.CONFLICT_BLOCKING_THRESHOLD
                      else SeveridadeConflito.WARNING)
        conflitos.append(ConflitoDetectado(
            tipo=TipoConflito.NUCLEO_REURB,
            entidade_id=row.nucleo_id,
            entidade_nome=row.nucleo_nome,
            sobreposicao_pct=round(row.pct, 2),
            sobreposicao_area_m2=round(row.area_m2, 2),
            severidade=severidade,
        ))

    # Check 2: Terras federais SPU (qualquer sobreposicao = BLOCKING)
    query_spu = text("""
        WITH target AS (
            SELECT ST_SetSRID(ST_GeomFromGeoJSON(:geojson), :srid) AS geom
        )
        SELECT
            s.id::text AS spu_id,
            s.tipo,
            s.orgao,
            ST_Area(ST_Intersection(s.geom, t.geom)) / ST_Area(t.geom) * 100 AS pct,
            ST_Area(ST_Transform(ST_Intersection(s.geom, t.geom), :utm_srid)) AS area_m2
        FROM geo.area_spu s
        CROSS JOIN target t
        WHERE ST_Intersects(s.geom, t.geom)
    """)

    result = await db.execute(query_spu, {
        "geojson": geojson_str,
        "srid": settings.SIRGAS2000_SRID,
        "utm_srid": settings.UTM_23S_SRID,
    })

    for row in result.fetchall():
        conflitos.append(ConflitoDetectado(
            tipo=TipoConflito.TERRA_FEDERAL_SPU,
            entidade_id=row.spu_id,
            entidade_nome=f"{row.tipo} ({row.orgao})",
            sobreposicao_pct=round(row.pct, 2),
            sobreposicao_area_m2=round(row.area_m2, 2),
            severidade=SeveridadeConflito.BLOCKING,
        ))

    # Check 3: Areas de protecao ambiental
    query_protecao = text("""
        WITH target AS (
            SELECT ST_SetSRID(ST_GeomFromGeoJSON(:geojson), :srid) AS geom
        )
        SELECT
            a.id::text AS area_id,
            a.nome,
            a.tipo,
            a.restricao,
            ST_Area(ST_Intersection(a.geom, t.geom)) / ST_Area(t.geom) * 100 AS pct,
            ST_Area(ST_Transform(ST_Intersection(a.geom, t.geom), :utm_srid)) AS area_m2
        FROM geo.area_protecao a
        CROSS JOIN target t
        WHERE ST_Intersects(a.geom, t.geom)
    """)

    result = await db.execute(query_protecao, {
        "geojson": geojson_str,
        "srid": settings.SIRGAS2000_SRID,
        "utm_srid": settings.UTM_23S_SRID,
    })

    for row in result.fetchall():
        # APP = sempre BLOCKING; APA = WARNING
        severidade = (SeveridadeConflito.BLOCKING
                      if row.tipo == "APP"
                      else SeveridadeConflito.WARNING)
        conflitos.append(ConflitoDetectado(
            tipo=TipoConflito.AREA_PROTECAO,
            entidade_id=row.area_id,
            entidade_nome=f"{row.nome} ({row.tipo})",
            sobreposicao_pct=round(row.pct, 2),
            sobreposicao_area_m2=round(row.area_m2, 2),
            severidade=severidade,
        ))

    elapsed_ms = int((time.time() - start_time) * 1000)
    tem_bloqueante = any(c.severidade == SeveridadeConflito.BLOCKING for c in conflitos)

    logger.info(
        "Verificacao de conflitos: nucleo=%s, conflitos=%d, bloqueante=%s, tempo=%dms",
        nucleo_id, len(conflitos), tem_bloqueante, elapsed_ms
    )

    return ConflictCheckResponse(
        tem_conflito_bloqueante=tem_bloqueante,
        conflitos=conflitos,
        tempo_processamento_ms=elapsed_ms,
    )
