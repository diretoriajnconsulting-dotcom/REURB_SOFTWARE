"""Configuracoes do servico geoespacial."""

from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    # Banco de dados
    DB_HOST: str = "localhost"
    DB_PORT: int = 5432
    DB_NAME: str = "datahub_fundiario"
    DB_USER: str = "datahub"
    DB_PASSWORD: str = "datahub_dev_2026"

    # Kafka
    KAFKA_SERVERS: str = "localhost:29092"

    # Redis
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379

    # GeoServer
    GEOSERVER_URL: str = "http://localhost:8600/geoserver"
    GEOSERVER_USER: str = "admin"
    GEOSERVER_PASSWORD: str = "geoserver_dev_2026"

    # CORS
    CORS_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:8080"]

    # Validacao espacial
    MIN_AREA_M2: float = 100.0  # Area minima de nucleo em m2
    CONFLICT_BLOCKING_THRESHOLD: float = 10.0  # % sobreposicao para BLOCKING
    SIRGAS2000_SRID: int = 4674  # EPSG:4674
    UTM_23S_SRID: int = 31983  # EPSG:31983 para calculo de area em PE

    @property
    def DATABASE_URL(self) -> str:
        return f"postgresql+asyncpg://{self.DB_USER}:{self.DB_PASSWORD}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"

    class Config:
        env_file = ".env"


settings = Settings()
