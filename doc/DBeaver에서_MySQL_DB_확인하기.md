# DBeaver에서 AeroGo MySQL DB 확인하기

이 문서는 로컬 Docker MySQL로 구성된 AeroGo DB를 DBeaver에서 확인하는 방법을 설명합니다.

## 1. MySQL 컨테이너 실행

프로젝트 루트에서 `.env` 파일을 먼저 준비합니다.

```powershell
Copy-Item .env.example .env
```

그다음 MySQL과 API 서버를 실행합니다.

```powershell
docker compose up -d mysql api
```

상태 확인:

```powershell
docker compose ps
```

`aerogo-mysql` 컨테이너가 `running` 또는 `healthy` 상태이면 DBeaver에서 접속할 수 있습니다.

## 2. DBeaver 연결 생성

1. DBeaver 실행
2. 상단 메뉴에서 `Database` → `New Database Connection`
3. DB 종류에서 `MySQL` 선택
4. `Next` 클릭

## 3. 접속 정보 입력

기본 `.env.example` 값을 그대로 사용했다면 다음처럼 입력합니다.

```text
Server Host: localhost
Port: 3306
Database: aerogo
Username: aerogo_app
Password: change_me_app_password
```

`.env`에서 값을 바꿨다면 DBeaver에도 동일하게 입력합니다.

## 4. 드라이버 다운로드

처음 MySQL 연결을 만들면 DBeaver가 MySQL JDBC Driver 다운로드를 요청할 수 있습니다.

1. `Download` 클릭
2. 다운로드 완료 후 `Test Connection` 클릭
3. `Connected` 메시지가 뜨면 성공

## 5. DB 구조 확인

연결 성공 후 왼쪽 Database Navigator에서 다음 순서로 펼칩니다.

```text
aerogo
└── Databases
    └── aerogo
        └── Tables
```

주요 테이블:

```text
users
email_verification_tokens
system_settings
game_records
game_moves
ai_analysis
training_datasets
admin_audit_logs
```

## 6. 공개 기보 500건 확인

DBeaver SQL Editor에서 다음 쿼리를 실행합니다.

```sql
SELECT COUNT(*) AS public_game_count
FROM game_records
WHERE source_name = 'yenw/computer-go-dataset Professional';
```

정상적으로 초기 데이터가 들어갔다면 `500`이 나옵니다.

상위 20건 확인:

```sql
SELECT
  id,
  title,
  black_player_name,
  white_player_name,
  result_text,
  winner,
  board_size,
  komi,
  started_at,
  source_record_id
FROM game_records
WHERE source_name = 'yenw/computer-go-dataset Professional'
ORDER BY id
LIMIT 20;
```

## 7. 사용자/관리자 계정 확인

```sql
SELECT
  id,
  email,
  role,
  status,
  email_verified,
  display_name,
  created_at
FROM users
ORDER BY id;
```

초기 seed에는 개발용 `admin@aerogo.local`, `guest@aerogo.local` 계정이 들어갑니다.

주의: 초기 seed의 비밀번호 해시는 placeholder입니다. 실제 로그인 가능한 관리자 계정을 만들려면 별도 관리자 생성 스크립트 또는 API를 추가해야 합니다.

## 8. 이메일 인증 대기 사용자 확인

회원가입 후 이메일 인증 전 사용자는 `pending_email` 상태입니다.

```sql
SELECT
  id,
  email,
  status,
  email_verified,
  email_verification_sent_at,
  email_confirmed_at
FROM users
WHERE status = 'pending_email'
ORDER BY created_at DESC;
```

인증 토큰 확인:

```sql
SELECT
  id,
  user_id,
  purpose,
  expires_at,
  used_at,
  created_at
FROM email_verification_tokens
ORDER BY created_at DESC
LIMIT 20;
```

## 9. 기존 DB에 500건 seed가 안 보이는 경우

Docker MySQL 볼륨이 이미 생성된 뒤 `04_public_game_records_seed.sql`이 추가되었다면, Docker 초기화 스크립트는 자동으로 다시 실행되지 않습니다.

이 경우 프로젝트 루트에서 수동으로 seed를 적용합니다.

```powershell
docker compose exec -T mysql mysql -u aerogo_app -p aerogo < database/mysql/04_public_game_records_seed.sql
```

비밀번호를 물어보면 `.env`의 `MYSQL_PASSWORD` 값을 입력합니다.

기본값:

```text
change_me_app_password
```

## 10. 접속이 안 될 때 확인할 것

### 컨테이너 상태 확인

```powershell
docker compose ps
```

### MySQL 로그 확인

```powershell
docker compose logs mysql
```

### 포트 충돌 확인

이미 PC에 MySQL이 설치되어 `3306` 포트를 쓰고 있으면 충돌할 수 있습니다.

`.env`에서 포트를 바꿉니다.

```text
MYSQL_PORT=3307
```

그 후 다시 실행합니다.

```powershell
docker compose up -d mysql api
```

DBeaver 접속 포트도 `3307`로 맞춥니다.

## 11. 추천 사용 방식

DBeaver에서는 DB 확인, seed 검증, 관리자용 데이터 점검만 하고, Flutter 앱은 MySQL에 직접 연결하지 않는 것을 권장합니다.

권장 구조:

```text
Flutter 앱
↓
FastAPI 백엔드
↓
MySQL
```

