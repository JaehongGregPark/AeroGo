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

    mysql_host: str = _env("MYSQL_HOST", "127.0.0.1")
    mysql_port: int = _env_int("MYSQL_PORT", 3306)
    mysql_database: str = _env("MYSQL_DATABASE", "aerogo")
    mysql_user: str = _env("MYSQL_USER", "aerogo_app")
    mysql_password: str = _env("MYSQL_PASSWORD", "change_me_app_password")

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
