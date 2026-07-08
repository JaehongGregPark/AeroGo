from dataclasses import dataclass
import os


def _env(name: str, default: str = "") -> str:
    return os.getenv(name, default)


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default


@dataclass(frozen=True)
class Settings:
    app_name: str = "AeroGo API"
    public_base_url: str = _env("PUBLIC_BASE_URL", "http://localhost:8000")
    email_verification_secret: str = _env(
        "EMAIL_VERIFICATION_SECRET",
        "change-me-email-verification-secret",
    )
    email_token_max_age_seconds: int = _env_int(
        "EMAIL_TOKEN_MAX_AGE_SECONDS",
        60 * 60 * 24,
    )
    session_max_age_seconds: int = _env_int(
        "SESSION_MAX_AGE_SECONDS",
        60 * 60 * 24 * 30,
    )

    # 기존엔 MySQL 전용이었으나, 통합 테스트 서버에서 MySQL/Postgres 두 엔진을
    # 같이 띄우는 대신 Postgres 하나로 EIPQuiz/aura와 통일하기 위해 전환.
    postgres_host: str = _env("POSTGRES_HOST", "127.0.0.1")
    postgres_port: int = _env_int("POSTGRES_PORT", 5432)
    postgres_database: str = _env("POSTGRES_DATABASE", "aerogo")
    postgres_user: str = _env("POSTGRES_USER", "aerogo_app")
    postgres_password: str = _env("POSTGRES_PASSWORD", "change_me_app_password")

    smtp_host: str = _env("SMTP_HOST", "")
    smtp_port: int = _env_int("SMTP_PORT", 587)
    smtp_user: str = _env("SMTP_USER", "")
    smtp_password: str = _env("SMTP_PASSWORD", "")
    smtp_use_tls: bool = _env("SMTP_USE_TLS", "true").lower() == "true"
    default_from_email: str = _env(
        "DEFAULT_FROM_EMAIL",
        "AeroGo <noreply@aerogo.local>",
    )


settings = Settings()
