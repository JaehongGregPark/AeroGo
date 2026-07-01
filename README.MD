# AeroGo

AeroGo는 Python으로 만드는 바둑 프로그램입니다. 현재 버전은 사람이 직접 둘 수 있는 데스크톱 바둑판, 기본 규칙 엔진, 계층형 메뉴, SGF 기보 저장/불러오기 기능을 제공합니다.

## 주요 기능

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
├── app.py                 # Tkinter GUI 앱 진입점
├── engine/
│   ├── board.py           # 바둑판, 그룹, 활로 계산
│   ├── game.py            # 대국 상태, 착수, 패스, Undo/Redo
│   ├── rules.py           # 착수 검증, 자살수, 패 규칙
│   └── sgf.py             # SGF 저장/불러오기
├── tests/
│   └── test_game.py       # 엔진 단위 테스트
└── doc/
    └── 바둑플로그램 단계별 가이드.txt
```

## 실행 준비사항

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

프로젝트 루트 폴더에서 실행합니다.

```powershell
python app.py
```

실행 후 상단 메뉴에서 다음 기능을 사용할 수 있습니다.

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

- 사람 vs AI 자동 착수
- AI vs AI 자동 대국
- MCTS 기반 난이도별 탐색
- 신경망 가중치 로드
- GPU 가속 연동
- 정확한 집 계산 및 고급 형세 분석
- 기보 데이터셋 학습 파이프라인

## 다음 개발 로드맵

1. MCTS 기반 간단한 AI 착수 엔진 추가
2. AI 난이도별 탐색 횟수 연결
3. SGF 호환성 강화
4. 집 계산 및 종국 판정 개선
5. 형세 분석 그래프 고도화
6. 신경망 모델 로드 및 학습 메뉴 실제 구현

