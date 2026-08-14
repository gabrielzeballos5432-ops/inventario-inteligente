from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    APP_NAME: str = "Inventario Inteligente - Salon de Belleza Zoom"
    VERSION: str = "1.0.0"
    DEBUG: bool = True

    DB_HOST: str = "localhost"
    DB_PORT: int = 5432
    DB_USER: str = "admin_user"
    DB_PASSWORD: str = "admin_password"
    DB_NAME: str = "inventario_db"

    @property
    def DATABASE_URL(self) -> str:
        return (
            f"postgresql+asyncpg://{self.DB_USER}:{self.DB_PASSWORD}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )

    SECRET_KEY: str = "cambiar_esta_clave_en_produccion"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480

    YOLO_MODEL_PATH: str = "app/models/best.pt"
    YOLO_CONFIDENCE_THRESHOLD: float = 0.5
    YOLO_CLASS_MAP: dict[int, int] = {}

    DEFAULT_ADMIN_USERNAME: str = "admin"
    DEFAULT_ADMIN_EMAIL: str = "admin@zoom.com"
    DEFAULT_ADMIN_PASSWORD: str = "Admin12345"

    CORS_ORIGINS: list[str] = ["http://localhost:4200", "http://127.0.0.1:4200"]

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
