from datetime import datetime, timedelta, timezone

from fastapi import FastAPI, HTTPException, Query, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, EmailStr, Field

from .config import settings
from .db import get_connection
from .emailer import send_verification_email
from .security import (
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
        cursor = connection.cursor(dictionary=True)
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
            """,
            (
                username,
                email,
                hash_password(payload.password),
                _utcnow(),
                payload.display_name.strip(),
            ),
        )
        user_id = cursor.lastrowid
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
        cursor = connection.cursor(dictionary=True)
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
        cursor = connection.cursor(dictionary=True)
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
        cursor = connection.cursor(dictionary=True)
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

    return AuthUserResponse(
        id=user["id"],
        email=user["email"],
        role=user["role"],
        status=user["status"],
        display_name=user["display_name"],
        email_verified=bool(user["email_verified"]),
    )
