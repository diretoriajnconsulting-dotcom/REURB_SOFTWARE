"""Schemas Pydantic para request/response do servico geoespacial."""

from pydantic import BaseModel, Field
from typing import Optional, List, Any
from enum import Enum
from uuid import UUID


class SeveridadeConflito(str, Enum):
    BLOCKING = "BLOCKING"
    WARNING = "WARNING"


class TipoConflito(str, Enum):
    REGISTRO_EXISTENTE = "REGISTRO_EXISTENTE"
    NUCLEO_REURB = "NUCLEO_REURB"
    TERRA_FEDERAL_SPU = "TERRA_FEDERAL_SPU"
    AREA_PROTECAO = "AREA_PROTECAO"


class ValidacaoErro(BaseModel):
    tipo: str
    mensagem: str
    vertice_problema: Optional[List[float]] = None


class ValidacaoResponse(BaseModel):
    is_valid: bool
    errors: List[ValidacaoErro] = []
    area_m2: Optional[float] = None
    srid_detectado: Optional[int] = None
    centroide: Optional[List[float]] = None


class UploadResponse(BaseModel):
    geojson: dict
    srid_original: Optional[int] = None
    srid_convertido: int = 4674
    area_m2: float
    vertices_count: int
    is_valid: bool
    preview_wms_url: Optional[str] = None


class ConflitoDetectado(BaseModel):
    tipo: TipoConflito
    entidade_id: Optional[str] = None
    entidade_nome: Optional[str] = None
    sobreposicao_pct: float
    sobreposicao_area_m2: Optional[float] = None
    severidade: SeveridadeConflito
    geometria_intersecao: Optional[dict] = None


class ConflictCheckRequest(BaseModel):
    nucleo_id: UUID
    geojson_polygon: dict


class ConflictCheckResponse(BaseModel):
    tem_conflito_bloqueante: bool
    conflitos: List[ConflitoDetectado] = []
    tempo_processamento_ms: int
