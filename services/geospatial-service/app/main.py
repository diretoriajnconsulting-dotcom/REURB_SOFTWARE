"""
Data Hub Fundiario — Geospatial Service
Servico de processamento geoespacial para validacao de poligonos,
deteccao de conflitos e transformacoes de coordenadas.
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router as api_router
from app.core.config import settings
from app.core.database import engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gerencia ciclo de vida da aplicacao."""
    yield
    await engine.dispose()


app = FastAPI(
    title="Data Hub Fundiario — Geospatial Service",
    description="Servico de processamento geoespacial: validacao de poligonos, "
                "deteccao de conflitos e transformacoes SIRGAS2000.",
    version="1.0.0",
    docs_url="/api/v1/geo/docs",
    openapi_url="/api/v1/geo/openapi.json",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1/geo")


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "geospatial-service"}
