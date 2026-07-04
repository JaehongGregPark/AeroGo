# AeroGo

AeroGo는 바둑 대국, AI 분석, 기보 관리, 관리자 기능을 목표로 만드는 바둑 프로그램입니다. 현재 프로젝트에는 Flutter 앱 버전과 기존 Python/Tkinter 참고 구현이 함께 있습니다.

Flutter 앱이 주력 버전이며, 바둑 규칙 엔진(`lib/game/go_engine.dart`)이 규칙의 기준(source of truth)입니다. `engine/` 아래의 Python 구현은 Tkinter 참고 앱(`app.py`) 전용 레거시 구현으로, Dart 엔진과 코드나 동작을 공유하지 않습니다. 두 엔진 간 관계와 정책은 [engine/README.md](engine/README.md)를 참고하세요.

Flutter 앱은 일반사용자와 관리자 역할을 구분합니다. 관리자는 사용자 메뉴를 모두 포함하며, 추가로 시스템 전체 환경관리, 사용자 관리, 기보관리 메뉴를 사용할 수 있습니다.

## 주요 기능

### Flutter 앱

- 일반사용자/관리자 역할 전환
- 역할별 계층형 메뉴
- 관리자 메뉴: 시스템 전체 환경관리, 사용자 관리, 기보관리
- 일반사용자 메일 아이디 회원가입
- 이메일 인증 메일 발송 및 이메일 컨펌
- 9x9, 13x13, 19x19 바둑판 선택
- 사람 vs 사람, 사람 vs AI, AI vs AI 대국 모드 메뉴
- AI 난이도 메뉴: 초급, 중급, 고급
- 사람 vs AI 자동 응수
- AI vs AI 자동 대국
- 난이도별 AI 수 선택: 초급 랜덤 합법수, 중급 포획/연결 휴리스틱, 고급 아타리/형세 가중치
- Flutter CustomPaint 기반 바둑판
- 착수, 포획, 자살수 금지, 패스, Undo, Redo
- 간단한 형세 분석 화면
- 학습 및 분석 화면 준비
- 설정 화면 준비

### Python 참고 구현

- 9x9, 13x13, 19x19 바둑판 선택
- 사람 vs 사람 대국
- 사람 vs AI, AI vs AI 메뉴 준비
- AI 난이도 메뉴 준비: 초급, 중급, 고급
- 착수, 포획, 자살수 금지, 단순 패 규칙
- 패스, Undo, Redo
- SGF 기보 저장/불러오기
- 간단한 형세 분석 팝업
- 학습 데이터셋 경로 선택 메뉴
- AI 모델 상태 확인 메뉴
- 바둑판 스킨 및 돌 디자인 변경
- CPU/GPU 설정 메뉴

## 프로젝트 구조

```text
AeroGo/
├── lib/
│   ├── main.dart          # Flutter 앱 진입점 (runApp만 담당)
│   ├── app.dart           # AeroGoApp (MaterialApp 설정)
│   ├── models/            # enums, MenuSection/MenuItem, 환경설정 모델
│   ├── game/
│   │   └── go_engine.dart # Dart 바둑 규칙 엔진 + 휴리스틱 AI (source of truth)
│   ├── widgets/            # 재사용 위젯 (헤더, 메뉴, 바둑판, 설정 패널 등)
│   └── screens/
│       └── home_page.dart # 메인 화면 상태 관리
├── pubspec.yaml           # Flutter 프로젝트 설정
├── docker-compose.yml     # 로컬 MySQL 실행 설정
├── backend/
│   ├── Dockerfile         # FastAPI 백엔드 컨테이너
│   ├── requirements.txt   # 백엔드 pip 패키지
│   └── app/
│       ├── main.py        # 회원가입/이메일 인증/세션 API
│       ├── security.py    # 비밀번호 해시와 인증 토큰
│       ├── emailer.py     # SMTP/개발용 콘솔 메일
│       └── db.py          # MySQL 연결
├── database/
│   └── mysql/
│       ├── 01_schema.sql  # MySQL 테이블/인덱스/제약조건
│       ├── 02_seed.sql    # 개발용 초기 데이터
│       ├── 04_public_game_records_seed.sql # 공개 프로 기보 메타데이터 500건
│       ├── 06_auth_sessions.sql # 로그인 세션 토큰 테이블
│       └── README.md      # MySQL 구성 안내
├── app.py                 # Tkinter GUI 앱 진입점
├── engine/
│   ├── README.md          # Python 엔진은 레거시 참고 구현이라는 점과 정책 설명
│   ├── board.py           # 바둑판, 그룹, 활로 계산
│   ├── game.py            # 대국 상태, 착수, 패스, Undo/Redo
│   ├── rules.py           # 착수 검증, 자살수, 패 규칙
│   └── sgf.py             # SGF 저장/불러오기
├── tests/
│   └── test_game.py       # Python 엔진 단위 테스트
├── test/
│   ├── go_game_test.dart  # Dart 엔진 단위 테스트
│   └── widget_test.dart   # AeroGoApp 스모크 테스트
└── doc/
    └── 바둑플로그램 단계별 가이드.txt
```

## 실행 준비사항

## Flutter 앱 실행 준비사항

### 1. Flutter SDK 설치

Flutter SDK 3.x 이상을 권장합니다.

설치 확인:

```powershell
flutter --version
```

개발 환경 점검:

```powershell
flutter doctor
```

`flutter doctor`에서 Android Studio, Chrome, Visual Studio, Windows desktop 같은 타겟별 요구사항을 안내합니다. 실행하려는 플랫폼에 맞게 필요한 항목을 설치합니다.

### 2. Flutter 의존성 준비

현재 Flutter 앱은 외부 pub 패키지를 사용하지 않습니다. Flutter SDK 기본 패키지만 필요합니다.

프로젝트 루트에서 다음 명령을 실행합니다.

```powershell
flutter pub get
```

### 3. 실행 가능한 디바이스 확인

```powershell
flutter devices
```

### 4. Flutter 앱 실행

연결된 기본 디바이스로 실행:

```powershell
flutter run
```

Windows 데스크톱으로 실행:

```powershell
flutter run -d windows
```

Chrome 웹으로 실행:

```powershell
flutter run -d chrome
```

### 5. Flutter 플랫폼 폴더 생성이 필요한 경우

현재 저장소에는 핵심 Flutter 소스(`pubspec.yaml`, `lib/main.dart`)가 추가되어 있습니다. Flutter SDK가 플랫폼 폴더 생성을 요구하면 프로젝트 루트에서 다음 명령을 실행합니다.

```powershell
flutter create .
flutter pub get
```

이 명령은 `android/`, `ios/`, `web/`, `windows/` 같은 플랫폼 폴더를 생성합니다.

## MySQL DB 및 API 구성

AeroGo는 관리자 기능, 기보 관리, 회원가입/이메일 인증을 위해 MySQL 스키마와 FastAPI 백엔드를 포함합니다. Flutter 앱이 MySQL에 직접 접속하는 구조는 권장하지 않습니다. 실제 서비스 구조는 다음 흐름을 사용합니다.

```text
Flutter 앱
↓
API 서버
↓
MySQL
```

### 1. Docker 준비

로컬 개발 DB는 Docker Compose로 실행할 수 있습니다.

```powershell
docker --version
docker compose version
```

### 2. 환경 변수 파일 생성

```powershell
Copy-Item .env.example .env
```

`.env` 파일에서 다음 값을 원하는 비밀번호로 변경합니다.

```text
MYSQL_DATABASE=aerogo
MYSQL_USER=aerogo_app
MYSQL_PASSWORD=change_me_app_password
MYSQL_ROOT_PASSWORD=change_me_root_password
MYSQL_PORT=3306
API_PORT=8000
PUBLIC_BASE_URL=http://localhost:8000
EMAIL_VERIFICATION_SECRET=change_me_to_a_long_random_secret
```

SMTP를 설정하지 않으면 개발 모드로 동작하며, 인증 링크가 API 서버 로그에 출력됩니다. 실제 메일 발송을 원하면 `.env`에 다음 값을 채웁니다.

```text
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=...
SMTP_PASSWORD=...
SMTP_USE_TLS=true
DEFAULT_FROM_EMAIL=AeroGo <noreply@example.com>
```

### 3. MySQL 및 API 실행

```powershell
docker compose up -d mysql api
```

처음 실행할 때 `database/mysql/01_schema.sql`, `database/mysql/02_seed.sql`, `database/mysql/03_email_auth_upgrade.sql`이 자동 적용됩니다.

공개 프로 기보 메타데이터 500건은 `database/mysql/04_public_game_records_seed.sql`에 포함되어 함께 적용됩니다. 이 seed는 `yenw/computer-go-dataset`의 Professional `pro2000+` 컬렉션에서 SGF 태그를 파싱해 생성했으며, SGF 착수 원문은 저장하지 않고 다음 메타데이터만 저장합니다.

- 대국명
- 흑/백 대국자
- 대국 결과
- 승자
- 날짜
- 덤
- 출처명/출처 URL/출처 레코드 ID

이미 MySQL 볼륨을 만든 뒤 seed를 추가했다면 Docker 초기화 스크립트가 자동 재실행되지 않습니다. 이 경우 수동으로 적용합니다.

```powershell
docker compose exec -T mysql mysql -u aerogo_app -p aerogo < database/mysql/04_public_game_records_seed.sql
```

### 4. 상태 확인

```powershell
docker compose ps
```

### 5. MySQL 접속

앱 사용자로 접속:

```powershell
docker compose exec mysql mysql -u aerogo_app -p aerogo
```

root 사용자로 접속:

```powershell
docker compose exec mysql mysql -u root -p
```

### 6. 구성된 주요 테이블

- `users`: 관리자/일반사용자 계정
- `email_verification_tokens`: 회원가입 이메일 인증 토큰
- `system_settings`: 시스템 전체 환경관리 설정
- `game_records`: 저장된 대국과 SGF 기보
- `game_moves`: 수순별 착수 기록
- `ai_analysis`: AI 형세 분석 결과
- `training_datasets`: 학습 데이터셋 관리
- `admin_audit_logs`: 관리자 작업 로그

초기 데이터에는 개발용 `admin`, `guest` 사용자가 포함됩니다. `password_hash`는 placeholder이므로 실제 API 서버를 만들 때 안전한 해시로 교체해야 합니다.

### 7. 회원가입/이메일 인증 API

일반사용자 가입 흐름은 LinguaUp 프로젝트와 같은 방식입니다.

```text
회원가입 요청
↓
users.status = pending_email
users.email_verified = false
↓
인증 메일 발송
↓
/auth/confirm-email?token=... 접속
↓
users.status = active
users.email_verified = true
```

주요 API:

```text
GET  /health
POST /auth/register
POST /auth/resend-verification
GET  /auth/confirm-email?token=...
POST /auth/login
POST /auth/logout
GET  /users/{user_id}/preferences/environment
PUT  /users/{user_id}/preferences/environment
```

`POST /auth/login`은 응답에 `session_token`과 `session_expires_at`을 포함합니다. `/auth/logout`과
`/users/{user_id}/preferences/environment` 두 엔드포인트는 `Authorization: Bearer <session_token>`
헤더가 필요하며, 본인 계정이 아니거나 관리자가 아니면 403을 반환합니다.

백엔드를 직접 실행하려면:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r backend\requirements.txt
uvicorn backend.app.main:app --reload
```

Flutter 앱의 `회원가입/이메일 인증` 메뉴에서 API 서버 주소를 `http://localhost:8000`으로 두고 가입을 테스트할 수 있습니다.

DBeaver에서 로컬 MySQL DB를 확인하는 방법은 [DBeaver에서 MySQL DB 확인하기](doc/DBeaver에서_MySQL_DB_확인하기.md)를 참고하세요.

## Python 참고 구현 실행 준비사항

### 1. Python 설치

Python 3.10 이상을 권장합니다.

설치 확인:

```powershell
python --version
```

### 2. pip 확인

현재 AeroGo는 외부 pip 패키지 없이 실행됩니다. 그래도 Python 환경 확인을 위해 pip가 동작하는지 확인합니다.

```powershell
python -m pip --version
```

pip 자체를 최신으로 갱신하려면 다음 명령을 사용할 수 있습니다.

```powershell
python -m pip install --upgrade pip
```

### 3. Tkinter 확인

GUI는 Python 표준 라이브러리인 Tkinter를 사용합니다. 일반적인 Windows Python 설치에는 함께 포함됩니다.

확인:

```powershell
python -m tkinter
```

작은 Tkinter 테스트 창이 뜨면 정상입니다.

### 4. 선택 사항: 가상환경 만들기

현재는 필수 의존성이 없지만, 이후 AI/MCTS/신경망 패키지를 추가할 계획이라면 가상환경 사용을 권장합니다.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
```

현재 버전에서 추가 설치할 패키지는 없습니다.

## 실행 방법

### Flutter 앱

프로젝트 루트 폴더에서 실행합니다.

```powershell
flutter run
```

### Python 참고 구현

```powershell
python app.py
```

## Flutter 앱 메뉴 구조

일반사용자 메뉴:

```text
계정
└── 회원가입/이메일 인증

새 게임 시작
├── 대국 환경 설정: 19x19, 13x13, 9x9
├── 대국 모드: 사람 vs 사람, 사람 vs AI, AI vs AI
├── AI 난이도 설정: 초급, 중급, 고급
└── 새 게임

대국 관리
├── Undo
├── Redo
├── 형세 분석
└── 기보 저장/불러오기

학습 및 분석
├── 기보 학습 모드
└── AI 모델 상태 확인

설정
├── 시각화 옵션
└── 환경 설정

종료
```

관리자 메뉴는 위 사용자 메뉴를 모두 포함하며, 다음 메뉴가 추가됩니다.

```text
관리자 메뉴
├── 시스템 전체 환경관리
├── 사용자 관리
└── 기보관리
```

## Python 참고 구현 메뉴 구조

Python 앱 실행 후 상단 메뉴에서 다음 기능을 사용할 수 있습니다.

```text
새 게임 시작
├── 대국 환경 설정: 19x19, 13x13, 9x9
├── 대국 모드: 사람 vs 사람, 사람 vs AI, AI vs AI
├── AI 난이도 설정: 초급, 중급, 고급
└── 새 게임 시작

대국 관리
├── 수 읽기 - Undo
├── 수 읽기 - Redo
├── 형세 분석
├── 기보 저장(SGF)
└── 기보 불러오기(SGF)

학습 및 분석
├── 기보 학습 모드
└── AI 모델 상태 확인

설정
├── 시각화 옵션
└── 환경 설정

종료
```

## 테스트 실행

### Flutter

Flutter SDK가 준비된 뒤 다음 명령을 실행합니다.

```powershell
flutter analyze
flutter test
```

### Backend

```powershell
python -m unittest discover -s backend/tests -v
python -m compileall backend
```

### Python

표준 라이브러리 `unittest`를 사용하므로 별도 패키지 설치가 필요 없습니다.

```powershell
python -m unittest discover -s tests -v
```

문법 검사 및 바이트코드 컴파일 확인:

```powershell
python -m compileall app.py engine tests
```

## 현재 구현된 규칙

- 빈 교차점에만 착수 가능
- 착수 후 상대 돌의 활로가 없으면 포획
- 상대 돌을 잡지 못하고 자기 돌의 활로도 없으면 자살수로 거부
- 바로 이전 판 상태로 되돌리는 단순 패 금지
- 양쪽이 연속으로 패스하면 대국 종료 상태

## 아직 준비 중인 기능

다음 메뉴는 UI에 포함되어 있지만, 실제 AI 엔진이나 학습 파이프라인은 다음 단계에서 연결해야 합니다.

- MCTS 기반 난이도별 탐색
- 신경망 가중치 로드
- GPU 가속 연동
- 정확한 집 계산 및 고급 형세 분석
- 기보 데이터셋 학습 파이프라인
- Flutter SGF 파일 저장/불러오기 실제 파일 연동
- 관리자 계정 인증 및 권한 저장소 연동

## 다음 개발 로드맵

1. MCTS 기반 간단한 AI 착수 엔진 추가
2. AI 난이도별 탐색 횟수 연결
3. SGF 호환성 강화
4. 집 계산 및 종국 판정 개선
5. 형세 분석 그래프 고도화
6. 신경망 모델 로드 및 학습 메뉴 실제 구현
7. 관리자 사용자/기보 데이터 저장소 연결
