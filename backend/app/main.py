import json
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, EmailStr, Field

from .config import settings
from .db import dict_cursor, get_connection
from .emailer import send_verification_email
from .security import (
    generate_session_token,
    hash_password,
    make_email_token,
    normalize_email,
    parse_email_token,
    token_hash,
    verify_password,
)


app = FastAPI(title=settings.app_name)


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=100)
    terms_accepted: bool


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class ResendVerificationRequest(BaseModel):
    email: EmailStr


class AuthUserResponse(BaseModel):
    id: int
    email: EmailStr
    role: str
    status: str
    display_name: str | None
    email_verified: bool
    session_token: str
    session_expires_at: datetime


class UserEnvironmentPreference(BaseModel):
    show_reference_diagram: bool = True
    auto_save_own_records: bool = True
    auto_save_observed_records: bool = False
    auto_replay_interval_seconds: int = Field(default=3, ge=1, le=360)
    show_move_numbers: bool = False
    play_stone_sound_in_game: bool = True
    play_stone_sound_in_record_review: bool = True
    play_countdown_sound: bool = True
    stone_sound_volume: Literal["loud", "normal", "small"] = "normal"
    countdown_voice: Literal["male", "female"] = "female"


ENVIRONMENT_PREFERENCE_KEY = "environment"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _verification_expires_at() -> datetime:
    return _utcnow() + timedelta(seconds=settings.email_token_max_age_seconds)


def _verification_url(token: str) -> str:
    return f"{settings.public_base_url.rstrip('/')}/auth/confirm-email?token={token}"


def _create_verification_token(connection, user_id: int, email: str) -> str:
    token = make_email_token(user_id, email)
    cursor = connection.cursor()
    cursor.execute(
        """
        INSERT INTO email_verification_tokens (
          user_id,
          token_hash,
          purpose,
          expires_at
        ) VALUES (%s, %s, 'signup_confirm', %s)
        """,
        (user_id, token_hash(token), _verification_expires_at()),
    )
    cursor.close()
    return token


def _send_signup_verification(connection, user_id: int, email: str) -> str:
    token = _create_verification_token(connection, user_id, email)
    verify_url = _verification_url(token)
    send_verification_email(email, verify_url)
    cursor = connection.cursor()
    cursor.execute(
        "UPDATE users SET email_verification_sent_at = %s WHERE id = %s",
        (_utcnow(), user_id),
    )
    cursor.close()
    return verify_url


def _ensure_user_exists(connection, user_id: int) -> None:
    cursor = dict_cursor(connection)
    cursor.execute("SELECT id FROM users WHERE id = %s", (user_id,))
    user = cursor.fetchone()
    cursor.close()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")


def _session_expires_at() -> datetime:
    return _utcnow() + timedelta(seconds=settings.session_max_age_seconds)


def _create_session(connection, user_id: int) -> tuple[str, datetime]:
    token = generate_session_token()
    expires_at = _session_expires_at()
    cursor = connection.cursor()
    cursor.execute(
        """
        INSERT INTO auth_sessions (user_id, token_hash, expires_at)
        VALUES (%s, %s, %s)
        """,
        (user_id, token_hash(token), expires_at),
    )
    cursor.close()
    return token, expires_at


def get_current_user(authorization: str | None = Header(default=None)) -> dict:
    """Resolve the caller from a `Authorization: Bearer <token>` header.

    Raises 401 if the header is missing/malformed or the session is
    unknown, revoked, or expired.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="인증 토큰이 필요합니다.",
        )
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="인증 토큰이 필요합니다.",
        )

    with get_connection() as connection:
        cursor = dict_cursor(connection)
        cursor.execute(
            """
            SELECT u.id, u.email, u.role, u.status, u.display_name, u.email_verified
            FROM auth_sessions AS s
            JOIN users AS u ON u.id = s.user_id
            WHERE s.token_hash = %s
              AND s.revoked_at IS NULL
              AND s.expires_at > %s
            """,
            (token_hash(token), _utcnow()),
        )
        user = cursor.fetchone()
        cursor.close()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="세션이 만료되었거나 유효하지 않습니다.",
        )
    return user


def _require_self_or_admin(current_user: dict, user_id: int) -> None:
    if current_user["role"] != "admin" and int(current_user["id"]) != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="다른 사용자의 정보에 접근할 수 없습니다.",
        )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/auth/register", status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest) -> dict[str, str]:
    if not payload.terms_accepted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="약관 동의가 필요합니다.",
        )

    email = normalize_email(str(payload.email))
    username = email
    with get_connection() as connection:
        cursor = dict_cursor(connection)
        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        if cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="이미 가입된 이메일 주소입니다.",
            )

        cursor.execute(
            """
            INSERT INTO users (
              username,
              email,
              password_hash,
              role,
              status,
              email_verified,
              terms_accepted_at,
              display_name
            ) VALUES (%s, %s, %s, 'user', 'pending_email', FALSE, %s, %s)
            RETURNING id
            """,
            (
                username,
                email,
                hash_password(payload.password),
                _utcnow(),
                payload.display_name.strip(),
            ),
        )
        # psycopg2 has no cursor.lastrowid (that's a mysql-connector attribute) -
        # RETURNING id above + fetchone() is the Postgres-native way to get the
        # new row's id from the same INSERT.
        user_id = cursor.fetchone()["id"]
        verify_url = _send_signup_verification(connection, user_id, email)
        cursor.close()

    response = {
        "message": "인증 메일을 발송했습니다. 메일함에서 인증 링크를 확인해 주세요.",
    }
    if not settings.smtp_host:
        response["development_verify_url"] = verify_url
    return response


@app.post("/auth/resend-verification")
def resend_verification(payload: ResendVerificationRequest) -> dict[str, str]:
    email = normalize_email(str(payload.email))
    with get_connection() as connection:
        cursor = dict_cursor(connection)
        cursor.execute(
            """
            SELECT id, email_verified, status
            FROM users
            WHERE email = %s
            """,
            (email,),
        )
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="가입된 이메일이 없습니다.")
        if user["email_verified"]:
            return {"message": "이미 이메일 인증이 완료된 계정입니다."}
        verify_url = _send_signup_verification(connection, int(user["id"]), email)
        cursor.close()

    response = {"message": "인증 메일을 다시 발송했습니다."}
    if not settings.smtp_host:
        response["development_verify_url"] = verify_url
    return response


@app.get("/auth/confirm-email", response_class=HTMLResponse)
def confirm_email(token: str = Query(min_length=10)) -> str:
    try:
        payload = parse_email_token(token)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="인증 링크가 올바르지 않거나 만료되었습니다.",
        )

    email = normalize_email(str(payload.get("email") or ""))
    user_id = int(payload.get("user_id") or 0)
    hashed = token_hash(token)

    with get_connection() as connection:
        cursor = dict_cursor(connection)
        cursor.execute(
            """
            SELECT id, used_at, expires_at
            FROM email_verification_tokens
            WHERE user_id = %s
              AND token_hash = %s
              AND purpose = 'signup_confirm'
            """,
            (user_id, hashed),
        )
        token_row = cursor.fetchone()
        if not token_row or token_row["used_at"] is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="인증 링크가 올바르지 않거나 이미 사용되었습니다.",
            )
        if token_row["expires_at"] < _utcnow():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="인증 링크가 만료되었습니다.",
            )

        cursor.execute(
            """
            SELECT id
            FROM users
            WHERE id = %s
              AND email = %s
            """,
            (user_id, email),
        )
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="인증 대상 계정을 찾을 수 없습니다.",
            )

        now = _utcnow()
        cursor.execute(
            """
            UPDATE users
            SET email_verified = TRUE,
                status = 'active',
                email_confirmed_at = %s
            WHERE id = %s
            """,
            (now, user_id),
        )
        cursor.execute(
            """
            UPDATE email_verification_tokens
            SET used_at = %s
            WHERE id = %s
            """,
            (now, token_row["id"]),
        )
        cursor.close()

    return """
    <html>
      <head><title>AeroGo 이메일 인증 완료</title></head>
      <body>
        <h1>이메일 인증이 완료되었습니다.</h1>
        <p>AeroGo 앱으로 돌아가 로그인해 주세요.</p>
      </body>
    </html>
    """


@app.post("/auth/login", response_model=AuthUserResponse)
def login(payload: LoginRequest) -> AuthUserResponse:
    email = normalize_email(str(payload.email))
    with get_connection() as connection:
        cursor = dict_cursor(connection)
        cursor.execute(
            """
            SELECT id, email, password_hash, role, status, display_name, email_verified
            FROM users
            WHERE email = %s
            """,
            (email,),
        )
        user = cursor.fetchone()
        if not user or not verify_password(payload.password, user["password_hash"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="이메일 또는 비밀번호가 올바르지 않습니다.",
            )
        if not user["email_verified"] or user["status"] == "pending_email":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="이메일 인증을 완료한 뒤 로그인해 주세요.",
            )
        if user["status"] != "active":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="비활성화되었거나 잠긴 계정입니다.",
            )
        cursor.execute(
            "UPDATE users SET last_login_at = %s WHERE id = %s",
            (_utcnow(), user["id"]),
        )
        cursor.close()
        session_token, session_expires_at = _create_session(connection, user["id"])

    return AuthUserResponse(
        id=user["id"],
        email=user["email"],
        role=user["role"],
        status=user["status"],
        display_name=user["display_name"],
        email_verified=bool(user["email_verified"]),
        session_token=session_token,
        session_expires_at=session_expires_at,
    )


@app.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(current_user: dict = Depends(get_current_user)) -> None:
    # get_current_user only resolves the user, not the raw token, so this
    # revokes every active session for the caller rather than just one.
    with get_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            """
            UPDATE auth_sessions
            SET revoked_at = %s
            WHERE user_id = %s AND revoked_at IS NULL
            """,
            (_utcnow(), current_user["id"]),
        )
        cursor.close()
    return None


@app.get(
    "/users/{user_id}/preferences/environment",
    response_model=UserEnvironmentPreference,
)
def get_environment_preference(
    user_id: int,
    current_user: dict = Depends(get_current_user),
) -> UserEnvironmentPreference:
    _require_self_or_admin(current_user, user_id)
    with get_connection() as connection:
        _ensure_user_exists(connection, user_id)
        cursor = dict_cursor(connection)
        cursor.execute(
            """
            SELECT preference_value
            FROM user_preferences
            WHERE user_id = %s
              AND preference_key = %s
            """,
            (user_id, ENVIRONMENT_PREFERENCE_KEY),
        )
        row = cursor.fetchone()
        cursor.close()

    if not row:
        return UserEnvironmentPreference()

    value = row["preference_value"]
    if isinstance(value, str):
        value = json.loads(value)
    return UserEnvironmentPreference.model_validate(value)


@app.put(
    "/users/{user_id}/preferences/environment",
    response_model=UserEnvironmentPreference,
)
def save_environment_preference(
    user_id: int,
    payload: UserEnvironmentPreference,
    current_user: dict = Depends(get_current_user),
) -> UserEnvironmentPreference:
    _require_self_or_admin(current_user, user_id)
    preference_json = json.dumps(payload.model_dump(), ensure_ascii=False)
    with get_connection() as connection:
        _ensure_user_exists(connection, user_id)
        cursor = connection.cursor()
        cursor.execute(
            """
            INSERT INTO user_preferences (
              user_id,
              preference_key,
              preference_value
            ) VALUES (%s, %s, %s)
            ON CONFLICT (user_id, preference_key) DO UPDATE SET
              preference_value = EXCLUDED.preference_value,
              updated_at = CURRENT_TIMESTAMP
            """,
            (user_id, ENVIRONMENT_PREFERENCE_KEY, preference_json),
        )
        cursor.close()

    return payload
