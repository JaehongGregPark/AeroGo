from email.message import EmailMessage
import smtplib

from .config import settings


def send_verification_email(email: str, verify_url: str) -> None:
    subject = "[AeroGo] 이메일 인증을 완료해 주세요"
    body = (
        "AeroGo 회원가입을 환영합니다.\n\n"
        "아래 링크를 눌러 이메일 인증을 완료해 주세요.\n"
        f"인증 링크: {verify_url}\n\n"
        "이 링크는 24시간 동안 유효합니다."
    )

    if not settings.smtp_host:
        print("=" * 72)
        print("AeroGo development email backend")
        print(f"To: {email}")
        print(f"Subject: {subject}")
        print(body)
        print("=" * 72)
        return

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = settings.default_from_email
    message["To"] = email
    message.set_content(body)

    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
        if settings.smtp_use_tls:
            smtp.starttls()
        if settings.smtp_user:
            smtp.login(settings.smtp_user, settings.smtp_password)
        smtp.send_message(message)
