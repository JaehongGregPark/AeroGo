import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk

from engine.board import BLACK, EMPTY, WHITE
from engine.game import AeroGoGame
from engine.sgf import load_sgf, save_sgf


BOARD_COLOR = "#d8a84f"
LINE_COLOR = "#2f2416"
STAR_COLOR = "#261b10"
BLACK_STONE = "#111111"
WHITE_STONE = "#f2eee7"
WHITE_OUTLINE = "#b7aea0"


class AeroGoApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("AeroGo")
        self.minsize(760, 720)

        self.game = AeroGoGame(size=19)
        self.cell = 32
        self.margin = 36
        self.hover = None
        self.size_var = tk.IntVar(value=self.game.board.size)
        self.mode_var = tk.StringVar(value="사람 vs 사람")
        self.difficulty_var = tk.StringVar(value="초급")
        self.skin_var = tk.StringVar(value="Classic")
        self.stone_var = tk.StringVar(value="Flat")
        self.acceleration_var = tk.StringVar(value="CPU")

        self._build_menu()
        self._build_layout()
        self._draw_board()

    def _build_menu(self):
        menubar = tk.Menu(self)

        new_game_menu = tk.Menu(menubar, tearoff=False)
        board_size_menu = tk.Menu(new_game_menu, tearoff=False)
        for size in (19, 13, 9):
            board_size_menu.add_radiobutton(
                label=f"{size}x{size}",
                variable=self.size_var,
                value=size,
                command=self.new_game,
            )
        new_game_menu.add_cascade(label="대국 환경 설정", menu=board_size_menu)

        mode_menu = tk.Menu(new_game_menu, tearoff=False)
        for mode in ("사람 vs 사람", "사람 vs AI", "AI vs AI"):
            mode_menu.add_radiobutton(
                label=mode,
                variable=self.mode_var,
                value=mode,
                command=self._mode_changed,
            )
        new_game_menu.add_cascade(label="대국 모드", menu=mode_menu)

        difficulty_menu = tk.Menu(new_game_menu, tearoff=False)
        for label in ("초급", "중급", "고급"):
            difficulty_menu.add_radiobutton(
                label=label,
                variable=self.difficulty_var,
                value=label,
                command=self._difficulty_changed,
            )
        new_game_menu.add_cascade(label="AI 난이도 설정", menu=difficulty_menu)
        new_game_menu.add_separator()
        new_game_menu.add_command(label="새 게임 시작", command=self.new_game)
        menubar.add_cascade(label="새 게임 시작", menu=new_game_menu)

        management_menu = tk.Menu(menubar, tearoff=False)
        management_menu.add_command(label="수 읽기 - Undo", command=self.undo)
        management_menu.add_command(label="수 읽기 - Redo", command=self.redo)
        management_menu.add_separator()
        management_menu.add_command(label="형세 분석", command=self.show_position_analysis)
        management_menu.add_separator()
        management_menu.add_command(label="기보 저장(SGF)", command=self.save_game)
        management_menu.add_command(label="기보 불러오기(SGF)", command=self.load_game)
        menubar.add_cascade(label="대국 관리", menu=management_menu)

        training_menu = tk.Menu(menubar, tearoff=False)
        training_menu.add_command(label="기보 학습 모드", command=self.choose_training_data)
        training_menu.add_command(label="AI 모델 상태 확인", command=self.show_model_status)
        menubar.add_cascade(label="학습 및 분석", menu=training_menu)

        settings_menu = tk.Menu(menubar, tearoff=False)
        visual_menu = tk.Menu(settings_menu, tearoff=False)
        for skin in ("Classic", "Dark", "Paper"):
            visual_menu.add_radiobutton(
                label=f"바둑판 스킨 - {skin}",
                variable=self.skin_var,
                value=skin,
                command=self.apply_visual_options,
            )
        visual_menu.add_separator()
        for stone in ("Flat", "Gloss"):
            visual_menu.add_radiobutton(
                label=f"돌 디자인 - {stone}",
                variable=self.stone_var,
                value=stone,
                command=self.apply_visual_options,
            )
        settings_menu.add_cascade(label="시각화 옵션", menu=visual_menu)

        acceleration_menu = tk.Menu(settings_menu, tearoff=False)
        for option in ("CPU", "GPU"):
            acceleration_menu.add_radiobutton(
                label=f"{option} 가속",
                variable=self.acceleration_var,
                value=option,
                command=self.show_acceleration_status,
            )
        settings_menu.add_cascade(label="환경 설정", menu=acceleration_menu)
        menubar.add_cascade(label="설정", menu=settings_menu)

        menubar.add_command(label="종료", command=self.destroy)
        self.config(menu=menubar)

    def _build_layout(self):
        root = ttk.Frame(self, padding=16)
        root.pack(fill=tk.BOTH, expand=True)

        toolbar = ttk.Frame(root)
        toolbar.pack(fill=tk.X)

        for size in (9, 13, 19):
            ttk.Radiobutton(
                toolbar,
                text=f"{size}x{size}",
                variable=self.size_var,
                value=size,
                command=self.new_game,
            ).pack(side=tk.LEFT, padx=(0, 10))

        ttk.Button(toolbar, text="Pass", command=self.pass_turn).pack(
            side=tk.LEFT, padx=(12, 4)
        )
        ttk.Button(toolbar, text="Undo", command=self.undo).pack(side=tk.LEFT, padx=4)
        ttk.Button(toolbar, text="Redo", command=self.redo).pack(side=tk.LEFT, padx=4)
        ttk.Button(toolbar, text="New Game", command=self.new_game).pack(
            side=tk.LEFT, padx=4
        )

        self.status_var = tk.StringVar()
        ttk.Label(toolbar, textvariable=self.status_var, anchor=tk.E).pack(
            side=tk.RIGHT, fill=tk.X, expand=True
        )

        self.canvas = tk.Canvas(root, bg=BOARD_COLOR, highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True, pady=(14, 0))
        self.canvas.bind("<Configure>", lambda _event: self._draw_board())
        self.canvas.bind("<Button-1>", self.on_click)
        self.canvas.bind("<Motion>", self.on_motion)
        self.canvas.bind("<Leave>", self.on_leave)

    def new_game(self):
        self.game.reset(size=self.size_var.get())
        self.hover = None
        self._draw_board()

    def pass_turn(self):
        self.game.pass_turn()
        self._draw_board()

    def undo(self):
        self.game.undo()
        self._draw_board()

    def redo(self):
        self.game.redo()
        self._draw_board()

    def save_game(self):
        path = filedialog.asksaveasfilename(
            title="SGF 기보 저장",
            defaultextension=".sgf",
            filetypes=[("SGF files", "*.sgf"), ("All files", "*.*")],
        )
        if not path:
            return
        with open(path, "w", encoding="utf-8") as file:
            file.write(save_sgf(self.game))
        self.game.last_message = "SGF saved."
        self._draw_board()

    def load_game(self):
        path = filedialog.askopenfilename(
            title="SGF 기보 불러오기",
            filetypes=[("SGF files", "*.sgf"), ("All files", "*.*")],
        )
        if not path:
            return
        with open(path, "r", encoding="utf-8") as file:
            self.game = load_sgf(file.read())
        self.size_var.set(self.game.board.size)
        self.hover = None
        self._draw_board()

    def show_position_analysis(self):
        black_stones = 0
        white_stones = 0
        for row in self.game.board.grid:
            black_stones += row.count(BLACK)
            white_stones += row.count(WHITE)
        black_score = black_stones + self.game.captures[BLACK]
        white_score = white_stones + self.game.captures[WHITE] + self.game.komi
        total = max(black_score + white_score, 1)
        black_width = int(36 * black_score / total)
        white_width = 36 - black_width
        graph = f"Black [{'#' * black_width}{'.' * white_width}] White"
        messagebox.showinfo(
            "형세 분석",
            "\n".join(
                [
                    graph,
                    f"Black estimate: {black_score:.1f}",
                    f"White estimate: {white_score:.1f}",
                    "정확한 집 계산 AI는 다음 단계에서 연결할 수 있습니다.",
                ]
            ),
        )

    def choose_training_data(self):
        path = filedialog.askopenfilename(
            title="기보 학습 데이터셋 선택",
            filetypes=[
                ("SGF or text files", "*.sgf *.txt"),
                ("All files", "*.*"),
            ],
        )
        if path:
            messagebox.showinfo(
                "기보 학습 모드",
                f"선택한 데이터셋:\n{path}\n\n학습 파이프라인은 아직 연결되지 않았습니다.",
            )

    def show_model_status(self):
        messagebox.showinfo(
            "AI 모델 상태",
            "현재 로드된 신경망 가중치가 없습니다.\nMCTS/신경망 엔진을 추가하면 이 메뉴에서 상태를 확인합니다.",
        )

    def _mode_changed(self):
        if self.mode_var.get() != "사람 vs 사람":
            messagebox.showinfo(
                "대국 모드",
                f"{self.mode_var.get()} 모드는 메뉴에 준비되었습니다.\nAI 착수 엔진은 다음 단계에서 연결할 수 있습니다.",
            )
        self._draw_board()

    def _difficulty_changed(self):
        visits = {"초급": 100, "중급": 800, "고급": 3000}[self.difficulty_var.get()]
        messagebox.showinfo(
            "AI 난이도 설정",
            f"{self.difficulty_var.get()} 난이도: MCTS 탐색 {visits}회 기준으로 설정했습니다.",
        )
        self._draw_board()

    def apply_visual_options(self):
        global BOARD_COLOR, LINE_COLOR, BLACK_STONE, WHITE_STONE, WHITE_OUTLINE
        if self.skin_var.get() == "Dark":
            BOARD_COLOR = "#7d5a2f"
            LINE_COLOR = "#1f160e"
        elif self.skin_var.get() == "Paper":
            BOARD_COLOR = "#e7d3a0"
            LINE_COLOR = "#504431"
        else:
            BOARD_COLOR = "#d8a84f"
            LINE_COLOR = "#2f2416"

        if self.stone_var.get() == "Gloss":
            BLACK_STONE = "#050505"
            WHITE_STONE = "#ffffff"
            WHITE_OUTLINE = "#918a80"
        else:
            BLACK_STONE = "#111111"
            WHITE_STONE = "#f2eee7"
            WHITE_OUTLINE = "#b7aea0"

        self.canvas.configure(bg=BOARD_COLOR)
        self._draw_board()

    def show_acceleration_status(self):
        if self.acceleration_var.get() == "GPU":
            messagebox.showinfo(
                "환경 설정",
                "GPU 가속이 선택되었습니다.\n현재 버전은 CPU 엔진으로 실행됩니다.",
            )
        else:
            messagebox.showinfo("환경 설정", "CPU 가속으로 설정했습니다.")
        self._draw_board()

    def on_click(self, event):
        point = self._event_to_point(event)
        if point is None or self.game.is_over():
            return
        row, col = point
        self.game.play(row, col)
        self._draw_board()

    def on_motion(self, event):
        self.hover = self._event_to_point(event)
        self._draw_board()

    def on_leave(self, _event):
        self.hover = None
        self._draw_board()

    def _event_to_point(self, event):
        size = self.game.board.size
        x0, y0 = self._origin()
        col = round((event.x - x0) / self.cell)
        row = round((event.y - y0) / self.cell)

        if not (0 <= row < size and 0 <= col < size):
            return None

        px = x0 + col * self.cell
        py = y0 + row * self.cell
        if abs(event.x - px) > self.cell * 0.42 or abs(event.y - py) > self.cell * 0.42:
            return None
        return row, col

    def _draw_board(self):
        self.canvas.delete("all")
        size = self.game.board.size
        width = max(self.canvas.winfo_width(), 1)
        height = max(self.canvas.winfo_height(), 1)
        board_span = min(width, height) - self.margin * 2
        self.cell = max(18, board_span // (size - 1))

        x0, y0 = self._origin()
        last = size - 1

        for i in range(size):
            pos = i * self.cell
            self.canvas.create_line(
                x0,
                y0 + pos,
                x0 + last * self.cell,
                y0 + pos,
                fill=LINE_COLOR,
                width=1,
            )
            self.canvas.create_line(
                x0 + pos,
                y0,
                x0 + pos,
                y0 + last * self.cell,
                fill=LINE_COLOR,
                width=1,
            )

        for row, col in self._star_points(size):
            self._circle(x0 + col * self.cell, y0 + row * self.cell, 4, STAR_COLOR)

        self._draw_hover(x0, y0)
        for row in range(size):
            for col in range(size):
                stone = self.game.board.get_stone(row, col)
                if stone != EMPTY:
                    self._draw_stone(x0, y0, row, col, stone)

        self._update_status()

    def _draw_hover(self, x0, y0):
        if self.hover is None or self.game.is_over():
            return
        row, col = self.hover
        if self.game.board.get_stone(row, col) != EMPTY:
            return
        color = BLACK_STONE if self.game.turn == BLACK else WHITE_STONE
        outline = BLACK_STONE if self.game.turn == BLACK else WHITE_OUTLINE
        cx = x0 + col * self.cell
        cy = y0 + row * self.cell
        radius = self.cell * 0.38
        self.canvas.create_oval(
            cx - radius,
            cy - radius,
            cx + radius,
            cy + radius,
            fill=color,
            outline=outline,
            stipple="gray50",
        )

    def _draw_stone(self, x0, y0, row, col, stone):
        cx = x0 + col * self.cell
        cy = y0 + row * self.cell
        radius = self.cell * 0.43
        if stone == BLACK:
            self.canvas.create_oval(
                cx - radius,
                cy - radius,
                cx + radius,
                cy + radius,
                fill=BLACK_STONE,
                outline="#000000",
            )
        else:
            self.canvas.create_oval(
                cx - radius,
                cy - radius,
                cx + radius,
                cy + radius,
                fill=WHITE_STONE,
                outline=WHITE_OUTLINE,
                width=2,
            )

    def _circle(self, cx, cy, radius, color):
        self.canvas.create_oval(
            cx - radius,
            cy - radius,
            cx + radius,
            cy + radius,
            fill=color,
            outline=color,
        )

    def _origin(self):
        size = self.game.board.size
        width = max(self.canvas.winfo_width(), 1)
        height = max(self.canvas.winfo_height(), 1)
        span = self.cell * (size - 1)
        return (width - span) / 2, (height - span) / 2

    def _star_points(self, size):
        if size == 9:
            points = [2, 4, 6]
        elif size == 13:
            points = [3, 6, 9]
        else:
            points = [3, 9, 15]
        return [(row, col) for row in points for col in points]

    def _update_status(self):
        turn = "Black" if self.game.turn == BLACK else "White"
        score = (
            f"Captures B {self.game.captures[BLACK]} "
            f"- W {self.game.captures[WHITE]}"
        )
        settings = (
            f"{self.mode_var.get()} | AI {self.difficulty_var.get()} "
            f"| {self.acceleration_var.get()}"
        )
        self.status_var.set(
            f"{turn} to play | {score} | {settings} | {self.game.last_message}"
        )


if __name__ == "__main__":
    AeroGoApp().mainloop()
