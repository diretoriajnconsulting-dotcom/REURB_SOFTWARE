"""Rotas da API do servico geoespacial."""

import logging
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.core.database import get_db
from app.models.schemas import (
    ConflictCheckRequest,
    ConflictCheckResponse,
    ValidacaoResponse,
)
from app.services.spatial_operations import validar_geometria, verificar_conflitos

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/validate", response_model=ValidacaoResponse)
async def validate_polygon(
    geojson_polygon: dict,
    db: AsyncSession = Depends(get_db),
):
    """
    Valida geometria de um poligono GeoJSON.
    Verifica: fechamento, auto-intersecao, area minima, CRS SIRGAS2000.
    """
    try:
        return await validar_geometria(db, geojson_polygon)
    except Exception as e:
        logger.error("Erro na validacao de geometria: %s", str(e))
        raise HTTPException(status_code=422, detail=f"Erro ao validar geometria: {str(e)}")


@router.post("/conflicts/check", response_model=ConflictCheckResponse)
async def check_conflicts(
    request: ConflictCheckRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Executa verificacao de conflitos geoespaciais contra todas as camadas:
    - Outros nucleos REURB
    - Terras federais (SPU)
    - Areas de protecao ambiental (APP/APA)
    """
    try:
        return await verificar_conflitos(db, request.nucleo_id, request.geojson_polygon)
    except Exception as e:
        logger.error("Erro na verificacao de conflitos: %s", str(e))
        raise HTTPException(status_code=500, detail=f"Erro ao verificar conflitos: {str(e)}")


@router.post("/upload")
async def upload_spatial_file(
    file: UploadFile = File(...),
    nucleo_id: UUID = Form(...),
    db: AsyncSession = Depends(get_db),
):
    """
    Upload de arquivo espacial (DWG, SHP, KML, GeoJSON).
    Converte automaticamente para geometria PostGIS em SIRGAS2000 (SRID 4674).
    """
    allowed_extensions = {".dwg", ".shp", ".kml", ".geojson", ".json", ".zip"}
    file_ext = "." + file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""

    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Formato nao suportado: {file_ext}. Formatos aceitos: {', '.join(allowed_extensions)}"
        )

    if file.size and file.size > 50 * 1024 * 1024:  # 50MB
        raise HTTPException(status_code=400, detail="Arquivo excede o limite de 50MB")

    # TODO: Implementar pipeline GDAL de conversao em Sprint 2
    return {
        "message": "Upload recebido. Processamento sera implementado no Sprint 2.",
        "filename": file.filename,
        "nucleo_id": str(nucleo_id),
        "size_bytes": file.size,
    }
