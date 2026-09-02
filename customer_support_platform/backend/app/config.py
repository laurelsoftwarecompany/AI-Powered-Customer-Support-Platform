from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str
    OPENAI_API_KEY: str
    JWT_SECRET_KEY: str

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()