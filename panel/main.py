import os
import random
import string
import ctypes
import subprocess
import hashlib
import sys
import tkinter as tk
from tkinter import messagebox, ttk
import customtkinter as ctk
from datetime import date, datetime

from config import SECRET_CONFIG
from github_manager import GithubManager

# ══════════════════════════════════════════════════════════════════════════════
#  HWID Authorization Check
# ══════════════════════════════════════════════════════════════════════════════
def get_hardware_id() -> str:
    """
    جيب الـ Hardware ID بنفس طريقة KeyAuth:
    Machine GUID من الـ registry → SHA256 UTF-8
    """
    try:
        result = subprocess.check_output(
            'powershell -Command "(Get-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\Cryptography -Name MachineGuid).MachineGuid"',
            shell=True,
            stderr=subprocess.DEVNULL,
            creationflags=0x08000000,
        ).decode().strip()
        if not result:
            return ""
        return hashlib.sha256(result.encode("utf-8")).hexdigest()
    except Exception:
        return ""


def check_hwid_authorization() -> bool:
    try:
        gm = GithubManager(SECRET_CONFIG)
        hwid_file_path = SECRET_CONFIG.get("Hardware_IDs_FILE_PATH", "HWID.txt")
        raw_text = gm.get_text(hwid_file_path)

        allowed_hwids = set()
        for line in raw_text.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if ":" in line:
                _, hwid_hash = line.split(":", 1)
                allowed_hwids.add(hwid_hash.strip().lower())
            else:
                allowed_hwids.add(line.lower())

        current_hwid = get_hardware_id()

        if not allowed_hwids or not current_hwid or current_hwid.lower() not in allowed_hwids:
            messagebox.showerror("خطأ", "حدث خطأ غير متوقع.")
            return False

        return True

    except Exception:
        messagebox.showerror("خطأ", "حدث خطأ غير متوقع.")
        return False


ctk.set_appearance_mode("dark")

# ── Palette ───────────────────────────────────────────────────────────────────
BG          = "#0f1117"
CARD        = "#1a1d27"
CARD2       = "#21253a"
BORDER      = "#2e3248"
ACCENT      = "#7c75fd"
ACCENT_HOV  = "#574fd6"
DANGER      = "#ff4757"
DANGER_HOV  = "#cc3545"
SUCCESS     = "#2ed573"
WARNING     = "#ffa502"
WARNING_HOV = "#cc8400"
TEXT        = "#e8eaf6"
TEXT_DIM    = "#8b92b8"
SIDE_W      = 180
DROP_BG     = "#13151f"
DROP_SEL    = "#2a2d45"


# ══════════════════════════════════════════════════════════════════════════════
#  SearchableCombo  –  Entry + Dropdown Listbox
# ══════════════════════════════════════════════════════════════════════════════
class SearchableCombo(ctk.CTkFrame):
    MAX_VISIBLE = 8

    def __init__(self, master, values=None, placeholder="اكتب للبحث...", **kwargs):
        super().__init__(master, fg_color="transparent", **kwargs)

        self._all_values   = list(values or [])
        self._select_cb    = None
        self._dropdown_win = None
        self._hover_idx    = -1
        self._clicking_lb  = False
        self._track_job    = None

        self._var = tk.StringVar()
        self._var.trace_add("write", self._on_type)
        self._suppress_trace = False

        self._entry = ctk.CTkEntry(
            self,
            textvariable=self._var,
            placeholder_text=placeholder,
            fg_color=CARD2,
            border_color=BORDER,
            border_width=1,
            text_color=TEXT,
            placeholder_text_color=TEXT_DIM,
            corner_radius=8,
            font=("Segoe UI", 13),
            height=36,
        )
        self._entry.pack(fill="x")

        self._entry.bind("<FocusIn>",  self._on_focus_in)
        self._entry.bind("<FocusOut>", self._on_focus_out)
        self._entry.bind("<Down>",     self._on_arrow_down)
        self._entry.bind("<Up>",       self._on_arrow_up)
        self._entry.bind("<Return>",   self._on_enter_key)
        self._entry.bind("<Escape>",   lambda e: self._close_dropdown())
        self._entry.bind("<Tab>",      self._on_tab)
        self._entry.bind("<Button-1>", self._on_entry_click)

    def _render_item(self, it):
        return f"  {it}"

    # ── Public API ─────────────────────────────────────────────────────────────
    def get(self):
        return self._var.get()

    def set(self, val):
        self._suppress_trace = True
        try:
            self._var.set(val)
        finally:
            self._suppress_trace = False
        try:
            self._entry._entry.icursor("end")
        except Exception:
            pass

    def set_values(self, lst):
        self._all_values = list(lst)
        if self._is_open():
            self._update_listbox(self._filtered())

    def bind_select(self, fn):
        self._select_cb = fn

    def focus(self):
        self._entry.focus()

    # ── Helpers ────────────────────────────────────────────────────────────────
    def _is_open(self):
        if self._dropdown_win is None:
            return False
        try:
            return self._dropdown_win.winfo_exists()
        except Exception:
            self._dropdown_win = None
            return False

    def _filtered(self):
        q = self._var.get().strip().lower()
        if not q:
            return self._all_values
        return [v for v in self._all_values if q in v.lower()]

    def _calc_pos(self):
        try:
            self._entry.update_idletasks()
            x = self._entry.winfo_rootx()
            y = self._entry.winfo_rooty() + self._entry.winfo_height() + 2
            w = self._entry.winfo_width()
            return x, y, w
        except Exception:
            return 0, 0, 200

    def _start_tracking(self):
        self._stop_tracking()
        self._track_job = self.after(50, self._track_loop)

    def _stop_tracking(self):
        if self._track_job:
            try:
                self.after_cancel(self._track_job)
            except Exception:
                pass
            self._track_job = None

    def _track_loop(self):
        if not self._is_open():
            self._stop_tracking()
            return
        x, y, w = self._calc_pos()
        if not self._is_open():
            return
        try:
            cur   = self._dropdown_win.geometry()
            parts = cur.split("+")
            if len(parts) == 3:
                cx, cy = int(parts[1]), int(parts[2])
                if cx != x or cy != y:
                    size = parts[0]
                    self._dropdown_win.geometry(f"{size}+{x}+{y}")
        except Exception:
            pass
        self._track_job = self.after(50, self._track_loop)

    # ── Events ─────────────────────────────────────────────────────────────────
    def _on_type(self, *_):
        if self._suppress_trace:
            return
        self._hover_idx = -1
        filtered = self._filtered()
        if filtered:
            if self._is_open():
                self._update_listbox(filtered)
            else:
                self._open_dropdown(filtered)
        else:
            self._close_dropdown()

    def _on_focus_in(self, _=None):
        self._entry.configure(border_color=ACCENT)

    def _on_entry_click(self, _=None):
        if self._is_open():
            self._close_dropdown()
        else:
            filtered = self._filtered()
            if filtered:
                self._open_dropdown(filtered)

    def _on_focus_out(self, _=None):
        self._entry.configure(border_color=BORDER)
        if self._clicking_lb:
            return
        self.after(150, self._maybe_close)

    def _maybe_close(self):
        if not self._clicking_lb:
            self._close_dropdown()

    def _on_arrow_down(self, _=None):
        if not self._is_open():
            self._open_dropdown(self._filtered())
            return "break"
        n = self._lb.size()
        if n == 0:
            return
        self._hover_idx = min(self._hover_idx + 1, n - 1)
        self._lb.selection_clear(0, "end")
        self._lb.selection_set(self._hover_idx)
        self._lb.see(self._hover_idx)
        return "break"

    def _on_arrow_up(self, _=None):
        if not self._is_open():
            return
        self._hover_idx = max(self._hover_idx - 1, 0)
        self._lb.selection_clear(0, "end")
        self._lb.selection_set(self._hover_idx)
        self._lb.see(self._hover_idx)
        return "break"

    def _on_enter_key(self, _=None):
        if self._is_open() and self._hover_idx >= 0:
            val = self._lb.get(self._hover_idx).strip()
            self._select(val)
            return "break"

    def _on_tab(self, _=None):
        if self._is_open() and self._lb.size():
            idx = self._hover_idx if self._hover_idx >= 0 else 0
            val = self._lb.get(idx).strip()
            self._select(val)
        self._close_dropdown()

    # ── Dropdown ───────────────────────────────────────────────────────────────
    def _open_dropdown(self, items):
        if not items:
            self._close_dropdown()
            return
        if self._is_open():
            self._update_listbox(items)
            return

        x, y, w = self._calc_pos()
        visible  = min(len(items), self.MAX_VISIBLE)
        row_h    = 20
        win_h    = visible * row_h + 4

        style = ttk.Style()
        style.theme_use("clam")
        style.configure(
            "Combo.Vertical.TScrollbar",
            gripcount=0, background=ACCENT, darkcolor=ACCENT,
            lightcolor=ACCENT, troughcolor=DROP_BG, bordercolor=DROP_BG,
            arrowcolor=DROP_BG, arrowsize=0, relief="flat", width=6,
        )
        style.map(
            "Combo.Vertical.TScrollbar",
            background=[("active", ACCENT_HOV), ("!active", ACCENT)],
        )

        root = self.winfo_toplevel()
        win  = tk.Toplevel(root)
        win.overrideredirect(True)
        win.configure(bg=BORDER)
        win.attributes("-topmost", True)

        inner = tk.Frame(win, bg=DROP_BG, bd=0)
        inner.pack(fill="both", expand=True, padx=1, pady=1)

        self._lb = tk.Listbox(
            inner,
            bg=DROP_BG, fg=TEXT,
            selectbackground=DROP_SEL, selectforeground=TEXT,
            activestyle="none", relief="flat", bd=0,
            highlightthickness=0, font=("Segoe UI", 12), height=visible,
        )

        if len(items) > self.MAX_VISIBLE:
            sb = ttk.Scrollbar(
                inner, orient="vertical",
                command=self._lb.yview,
                style="Combo.Vertical.TScrollbar",
            )
            sb.pack(side="right", fill="y", pady=2)
            self._lb.configure(yscrollcommand=sb.set)
            self._lb.bind("<MouseWheel>",
                lambda e: self._lb.yview_scroll(int(-1*(e.delta/120)), "units"))

        self._lb.pack(side="left", fill="both", expand=True)

        for it in items:
            self._lb.insert("end", self._render_item(it))

        self._lb.bind("<ButtonPress-1>",   self._lb_press)
        self._lb.bind("<ButtonRelease-1>", self._lb_release)
        self._lb.bind("<Motion>",          self._lb_motion)

        win.geometry(f"{w}x{win_h}+{x}+{y}")
        self._dropdown_win = win
        win.bind("<Destroy>", self._on_destroy)

        self._start_tracking()

    def _update_listbox(self, items):
        if not self._is_open():
            return
        self._lb.delete(0, "end")
        visible = min(len(items), self.MAX_VISIBLE)
        self._lb.configure(height=visible)
        for it in items:
            self._lb.insert("end", self._render_item(it))
        x, y, w = self._calc_pos()
        win_h = visible * 20 + 4
        if not self._is_open():
            return
        try:
            self._dropdown_win.geometry(f"{w}x{win_h}+{x}+{y}")
        except Exception:
            pass

    def _close_dropdown(self):
        self._stop_tracking()
        self._clicking_lb = False
        if self._is_open():
            self._dropdown_win.destroy()
        self._dropdown_win = None
        self._hover_idx    = -1

    def _on_destroy(self, _=None):
        self._stop_tracking()
        self._dropdown_win = None
        self._hover_idx    = -1
        self._clicking_lb  = False

    def _lb_press(self, _=None):
        self._clicking_lb = True

    def _lb_release(self, _=None):
        self._clicking_lb = False
        sel = self._lb.curselection()
        if sel:
            val = self._lb.get(sel[0]).strip()
            self._select(val)

    def _lb_motion(self, event):
        if not self._is_open():
            return
        idx = self._lb.nearest(event.y)
        if idx < 0: return
        self._lb.selection_clear(0, "end")
        self._lb.selection_set(idx)
        self._hover_idx = idx

    def _select(self, val):
        self._clicking_lb = False
        self._var.set(val)
        self._close_dropdown()
        self._entry.configure(border_color=BORDER)
        try:
            self._entry._entry.icursor("end")
        except Exception:
            pass
        if self._select_cb:
            self._select_cb(val)


# ══════════════════════════════════════════════════════════════════════════════
#  MultiSelectCombo  –  SearchableCombo مع اختيار أكواد متعددة
# ══════════════════════════════════════════════════════════════════════════════
class MultiSelectCombo(SearchableCombo):
    def __init__(self, master, values=None, placeholder="ابحث واختار أكواد متعددة...",
                 on_change=None, **kwargs):
        self._selected  = set()
        self._on_change = on_change
        super().__init__(master, values=values, placeholder=placeholder, **kwargs)

        self._summary = ctk.CTkLabel(
            self, text="لم يتم اختيار أي كود",
            font=("Segoe UI", 11), text_color=TEXT_DIM, anchor="e",
            wraplength=400, justify="right",
        )
        self._summary.pack(anchor="e", pady=(4, 0), fill="x")

    # ── Overrides: keep dropdown fixed, don't auto-close on focus loss ──────────
    def _on_focus_out(self, _=None):
        self._entry.configure(border_color=BORDER)

    def _maybe_close(self):
        pass

    def _start_tracking(self):
        # No position tracking: dropdown stays put, doesn't follow/move.
        pass

    def _stop_tracking(self):
        pass

    def _update_listbox(self, items):
        # نفس التحديث لكن بدون تغيير موضع النافذة (تفضل ثابتة مكان ما المستخدم واقف)
        if not self._is_open():
            return
        # حفظ موضع السكرول الحالي قبل إعادة التعبئة
        try:
            top_pos = self._lb.yview()[0]
        except Exception:
            top_pos = 0.0
        self._lb.delete(0, "end")
        visible = min(len(items), self.MAX_VISIBLE)
        self._lb.configure(height=visible)
        for it in items:
            self._lb.insert("end", self._render_item(it))
        # استرجاع موضع السكرول بعد إعادة التعبئة (القائمة تفضل ثابتة)
        try:
            self._lb.yview_moveto(top_pos)
        except Exception:
            pass

    def _render_item(self, it):
        mark = "✅" if it in self._selected else "▫️"
        return f"  {mark}  {it}"

    def _strip_item(self, text):
        return text.strip().lstrip("✅▫️").strip()

    def _select(self, val):
        val = self._strip_item(val)
        if not val:
            return
        if val in self._selected:
            self._selected.discard(val)
        else:
            self._selected.add(val)
        self._update_summary()
        if self._is_open():
            self._update_listbox(self._filtered())

    def get_selected(self):
        return sorted(self._selected)

    def clear_selection(self):
        self._selected.clear()
        self._suppress_trace = True
        try:
            self._var.set("")
        finally:
            self._suppress_trace = False
        self._update_summary()
        if self._is_open():
            self._update_listbox(self._filtered())
        else:
            self._close_dropdown()

    def set_values(self, lst):
        self._all_values = list(lst)
        self._selected = {v for v in self._selected if v in self._all_values}
        self._update_summary()
        if self._is_open():
            self._update_listbox(self._filtered())

    def _update_summary(self):
        n = len(self._selected)
        if n == 0:
            self._summary.configure(text="لم يتم اختيار أي كود")
        else:
            names = "، ".join(self.get_selected())
            self._summary.configure(text=f"✅ تم اختيار {n} كود: {names}")
        if self._on_change:
            self._on_change()


# ══════════════════════════════════════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════════════════════════════════════
def label(parent, text, small=False):
    return ctk.CTkLabel(
        parent, text=text,
        text_color=TEXT_DIM if small else TEXT,
        font=("Segoe UI", 11 if small else 13),
        anchor="e",
    )


def field(parent, placeholder="", width=None):
    kw = dict(
        placeholder_text=placeholder,
        fg_color=CARD2, border_color=BORDER, border_width=1,
        text_color=TEXT, placeholder_text_color=TEXT_DIM,
        corner_radius=8, font=("Segoe UI", 13), height=36,
    )
    if width:
        kw["width"] = width
    return ctk.CTkEntry(parent, **kw)


def btn(parent, text, command, color=ACCENT, hover=ACCENT_HOV, width=160):
    return ctk.CTkButton(
        parent, text=text, command=command,
        fg_color=color, hover_color=hover,
        corner_radius=8, font=("Segoe UI", 13, "bold"),
        height=38, width=width,
    )


def labeled_field(parent, lbl, placeholder="", fill=True):
    label(parent, lbl, small=True).pack(anchor="e", pady=(6, 1))
    e = field(parent, placeholder)
    e.pack(fill="x" if fill else None, padx=0, pady=0)
    return e


def labeled_searchable(parent, lbl, placeholder="اكتب للبحث..."):
    label(parent, lbl, small=True).pack(anchor="e", pady=(6, 1))
    sc = SearchableCombo(parent, placeholder=placeholder)
    sc.pack(fill="x")
    return sc


# ══════════════════════════════════════════════════════════════════════════════
#  Main App
# ══════════════════════════════════════════════════════════════════════════════
class App(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.geometry("1100x720")
        self.minsize(900, 600)
        self.title("PANDA Keys Manager")
        self.configure(fg_color=BG)

        # ── حل مشكلة أيقونة شريط المهام في ويندوز (Taskbar Icon Fix) ──
        try:
            myappid = 'mycompany.pandakeysmanager.version.1.0'
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)
        except Exception:
            pass

        # ── تركيب الأيقونة بجودة عالية ──
        icon_path = os.path.join(os.path.dirname(__file__), "panda_icon.ico")
        if os.path.exists(icon_path):
            try:
                self.iconbitmap(icon_path)
            except Exception:
                try:
                    import importlib
                    Image = importlib.import_module("PIL.Image")
                    img = Image.open(icon_path).convert("RGBA")
                    photo = ctk.CTkImage(light_image=img, dark_image=img, size=(32, 32))
                    self._icon_photo = photo
                    self.wm_iconphoto(True, photo)
                except Exception:
                    pass

        # ── بوابة كلمة المرور ──────────────────────────────────────────
        app_password = SECRET_CONFIG.get("APP_PASSWORD", "27122008")
        if app_password:
            self._build_password_gate(app_password)
        else:
            self._init_main_app()

    # ── بوابة كلمة المرور (شاشة احترافية + إظهار/إخفاء، بدون عدد محاولات) ──
    def _build_password_gate(self, app_password):
        self._gate = ctk.CTkFrame(self, fg_color=BG)
        self._gate.pack(fill="both", expand=True)

        card = ctk.CTkFrame(self._gate, fg_color=CARD, corner_radius=18, width=450, height=350)
        card.place(relx=0.5, rely=0.5, anchor="center")
        card.pack_propagate(False)

        ctk.CTkLabel(card, text="🐼", font=("Segoe UI", 44)).pack(pady=(40, 6))
        ctk.CTkLabel(
            card, text="PANDA Keys Manager",
            font=("Segoe UI", 17, "bold"), text_color=TEXT,
        ).pack()
        ctk.CTkLabel(
            card, text="ادخل كلمة المرور للوصول إلى البرنامج",
            font=("Segoe UI", 12), text_color=TEXT_DIM,
        ).pack(pady=(4, 22))

        entry_wrap = ctk.CTkFrame(card, fg_color="transparent")
        entry_wrap.pack(fill="x", padx=30)
        entry_wrap.grid_columnconfigure(0, weight=1)

        pw_var = tk.StringVar()
        entry = ctk.CTkEntry(
            entry_wrap, textvariable=pw_var, show="*", justify="center",
            fg_color=CARD2, border_color=BORDER, border_width=1,
            text_color=TEXT, placeholder_text_color=TEXT_DIM,
            corner_radius=8, font=("Segoe UI", 14), height=42,
            placeholder_text="كلمة المرور",
        )
        entry.grid(row=0, column=0, sticky="ew")
        entry.focus_set()

        def toggle_show():
            if entry.cget("show") == "":
                entry.configure(show="*")
                eye_btn.configure(text="👁")
            else:
                entry.configure(show="")
                eye_btn.configure(text="🙈")

        eye_btn = ctk.CTkButton(
            entry_wrap, text="👁", command=toggle_show, width=42, height=42,
            fg_color=CARD2, hover_color=BORDER, text_color=TEXT,
            corner_radius=8, font=("Segoe UI", 14),
        )
        eye_btn.grid(row=0, column=1, padx=(6, 0))

        err_label = ctk.CTkLabel(card, text="", font=("Segoe UI", 11), text_color=DANGER)
        err_label.pack(pady=(8, 0))

        def try_login(_=None):
            if pw_var.get() == app_password:
                self._gate.destroy()
                self._init_main_app()
            else:
                pw_var.set("")
                err_label.configure(text="❌ كلمة المرور غير صحيحة")
                entry.focus_set()

        entry.bind("<Return>", try_login)

        login_btn = ctk.CTkButton(
            card, text="دخول", command=try_login,
            fg_color=ACCENT, hover_color=ACCENT_HOV, text_color="#ffffff",
            corner_radius=10, height=42, font=("Segoe UI", 14, "bold"),
        )
        login_btn.pack(fill="x", padx=30, pady=(18, 0))

    # ── بناء التطبيق الأساسي بعد نجاح تسجيل الدخول ──────────────────────────
    def _init_main_app(self):
        self.bind("<Configure>", self._on_win_configure)
        self.bind_all("<ButtonPress-1>", self._on_global_click, add=True)

        # ── بيانات ────────────────────────────────────────────────────────
        self.gm                = GithubManager(SECRET_CONFIG)
        self.keys_data         = []
        self.current_sha       = None
        self.selected_key_data = None
        self.ban_data          = []
        self.ban_sha           = None
        # General keys state
        self.general_keys_data         = []
        self.general_keys_sha          = None
        self.selected_general_key_data = None
        self._general_device_map       = {}

        self.duration_map = {
            "ثانية":      "durationSeconds",
            "دقيقة":      "durationMinutes",
            "ساعة":       "durationHours",
            "يوم":        "durationDays",
            "أسبوع":      "durationWeeks",
            "شهر":        "durationMonths",
            "سنة":        "durationYears",
            "مدى الحياة": "durationDays",
        }

        self._build_layout()
        self.refresh()

    # ── مسح التحديد ──────────────────────────────────────────────────────────
    def _on_global_click(self, event):
        if isinstance(event.widget, (tk.Listbox, tk.Entry, tk.Text)):
            return
        self.after_idle(self._clear_all_selections)

    def _clear_all_selections(self):
        try:
            focused_widget = self.focus_get()
            if focused_widget and isinstance(focused_widget, tk.Entry):
                focused_widget.selection_clear()
            self.focus_set()
        except Exception:
            pass

    def _on_win_configure(self, e=None):
        # تجاهل أي Configure events غير ناتجة عن تغيير حجم/مكان نافذة التطبيق
        # نفسها (مثل التغييرات الناتجة عن إعادة تحجيم القائمة المنسدلة)
        if e is not None and e.widget is not self:
            return
        self._close_all_dropdowns()

    # ── Layout ───────────────────────────────────────────────────────────────
    def _build_layout(self):
        root = ctk.CTkFrame(self, fg_color=BG)
        root.pack(fill="both", expand=True)

        self._build_sidebar(root)

        self.content = ctk.CTkFrame(root, fg_color=BG)
        self.content.pack(side="left", fill="both", expand=True, padx=(0, 16), pady=16)

        self.pages = {}
        self._page_canvases = {}
        for name in ("create", "edit", "delete", "ban", "general"):
            sf = ctk.CTkScrollableFrame(
                self.content, fg_color=BG, scrollbar_button_color=BORDER
            )
            self.pages[name] = sf

            internal_canvas = None
            for attr in ['_canvas', '_parent_canvas', 'canvas']:
                if hasattr(sf, attr):
                    internal_canvas = getattr(sf, attr)
                    break

            self._page_canvases[name] = internal_canvas

            if internal_canvas:
                def custom_scroll(event, canvas_obj=internal_canvas):
                    canvas_obj.yview_scroll(int(-1 * (event.delta / 120)) * 3, "units")
                    return "break"

                internal_canvas.bind("<MouseWheel>", custom_scroll)

                for frame_attr in ['_internal_frame', '_frame', 'frame']:
                    if hasattr(sf, frame_attr):
                        getattr(sf, frame_attr).bind("<MouseWheel>", custom_scroll)
                        break

                sf.bind("<MouseWheel>", custom_scroll)

        self._build_create_page(self.pages["create"])
        self._build_edit_page(self.pages["edit"])
        self._build_delete_page(self.pages["delete"])
        self._build_ban_page(self.pages["ban"])
        self._build_general_page(self.pages["general"])

        # ── ربط عجلة الماوس بكل العناصر داخل كل صفحة (لحل مشكلة السكرول البطيء) ──
        for name, sf in self.pages.items():
            canvas = self._page_canvases.get(name)
            if canvas:
                self._bind_scroll_recursive(sf, canvas)

        self._show_page("create")

    def _bind_scroll_recursive(self, widget, canvas):
        def _scroll(event):
            canvas.yview_scroll(int(-20 * (event.delta / 120)) * 3, "units")
            return "break"

        try:
            widget.bind("<MouseWheel>", _scroll, add="+")
        except Exception:
            pass

        for child in widget.winfo_children():
            self._bind_scroll_recursive(child, canvas)

    def _build_sidebar(self, parent):
        side = ctk.CTkFrame(parent, width=SIDE_W, fg_color=CARD, corner_radius=0)
        side.pack(side="left", fill="y")
        side.pack_propagate(False)

        ctk.CTkLabel(side, text="🐼", font=("Segoe UI", 32)).pack(pady=(24, 0))
        ctk.CTkLabel(
            side, text="PANDA\nKeys Manager",
            font=("Segoe UI", 13, "bold"), text_color=TEXT, justify="center",
        ).pack(pady=(4, 20))

        ctk.CTkFrame(side, height=1, fg_color=BORDER).pack(fill="x", padx=16)

        nav_items = [
            ("➕  إنشاء كود",   "create"),
            ("✏️  تعديل كود",   "edit"),
            ("🗑  حذف كود",     "delete"),
            ("🚫  بان",          "ban"),
            ("🌐  أكواد عامة",   "general"),
        ]
        self.nav_btns = {}
        for text, page in nav_items:
            b = ctk.CTkButton(
                side, text=text,
                command=lambda p=page: self._show_page(p),
                fg_color="transparent", hover_color=CARD2,
                text_color=TEXT_DIM, anchor="w",
                font=("Segoe UI", 13), corner_radius=8, height=42,
            )
            b.pack(fill="x", padx=12, pady=3)
            self.nav_btns[page] = b

        def _fix_hover(b, pg):
            def _leave(e):
                current = getattr(self, "_current_page", "create")
                if pg != current:
                    b.configure(fg_color="transparent")
            try:
                b._canvas.bind("<Leave>", _leave, add=True)
            except Exception:
                pass
            for child in b.winfo_children():
                try:
                    child.bind("<Leave>", _leave, add=True)
                except Exception:
                    pass

        for pg, b in self.nav_btns.items():
            _fix_hover(b, pg)

        bottom = ctk.CTkFrame(side, fg_color="transparent")
        bottom.pack(side="bottom", fill="x", padx=12, pady=16)

        ctk.CTkFrame(bottom, height=1, fg_color=BORDER).pack(fill="x", pady=(0, 10))

        self.count_label = ctk.CTkLabel(
            bottom, text="الأكواد: ...",
            font=("Segoe UI", 12), text_color=TEXT_DIM,
        )
        self.count_label.pack()

        self.general_count_label = ctk.CTkLabel(
            bottom, text="العامة: ...",
            font=("Segoe UI", 12), text_color=TEXT_DIM,
        )
        self.general_count_label.pack()

        btn(bottom, "🔄 تحديث البيانات", self.refresh, width=SIDE_W - 24).pack(pady=(8, 4))

        btn(
            bottom, "♻️ إعادة تحميل",
            self._restart_app,
            color=CARD2, hover="#2e3360", width=SIDE_W - 24
        ).pack(pady=4)

    def _show_page(self, name):
        self._current_page = name
        for p in self.pages.values():
            p.pack_forget()
        self.pages[name].pack(fill="both", expand=True, padx=20, pady=20)

        for k, b in self.nav_btns.items():
            b.configure(
                fg_color=ACCENT if k == name else "transparent",
                text_color="#ffffff" if k == name else TEXT_DIM,
            )

    def _restart_app(self):
        current_page = getattr(self, "_current_page", "create")
        self._close_all_dropdowns()
        self.after_idle(self._clear_all_selections)

        self.selected_key_data         = None
        self.selected_general_key_data = None
        self._general_device_map       = {}

        # تصفير صفحة الإنشاء (كود عادي)
        try:
            for attr in ("create_key_entry", "create_comment_entry", "create_amount_entry",
                         "create_count_entry", "create_hwid_entry", "create_mac_entry"):
                if hasattr(self, attr):
                    getattr(self, attr).delete(0, "end")
            if hasattr(self, "create_duration_sc"):
                self.create_duration_sc.set("")
            if hasattr(self, "create_enabled"):
                self.create_enabled.select()
        except Exception:
            pass

        # تصفير صفحة التعديل (كود عادي)
        try:
            widgets_to_clear = [
                "edit_key_name", "edit_comment_entry", "edit_amount_entry",
                "edit_activation_entry", "edit_expiry_entry", "edit_hwid_entry", "edit_mac_entry"
            ]
            for attr in widgets_to_clear:
                if hasattr(self, attr):
                    getattr(self, attr).delete(0, "end")
            
            if hasattr(self, "edit_duration_sc"):
                self.edit_duration_sc.set("")
            if hasattr(self, "edit_enabled"):
                self.edit_enabled.deselect()
            if hasattr(self, "edit_key_sc"):
                self.edit_key_sc.set("")
        except Exception:
            pass

        # تصفير صفحة الحذف (كود عادي)
        try:
            if hasattr(self, "delete_key_sc"):
                self.delete_key_sc.set("")
            if hasattr(self, "delete_multi_combo"):
                self.delete_multi_combo.clear_selection()
        except Exception:
            pass

        # تصفير صفحة البان
        try:
            ban_widgets = ["ban_hwid_entry", "ban_mac_entry", "ban_reason_entry"]
            for attr in ban_widgets:
                if hasattr(self, attr):
                    getattr(self, attr).delete(0, "end")
            if hasattr(self, "ban_date_entry"):
                self.ban_date_entry.delete(0, "end")
                self.ban_date_entry.insert(0, datetime.now().strftime("%Y-%m-%d %I:%M:%S %p"))
            if hasattr(self, "ban_duration_sc"):
                self.ban_duration_sc.set("")
            if hasattr(self, "ban_amount_entry"):
                self.ban_amount_entry.delete(0, "end")
            if hasattr(self, "ban_key_sc"):
                self.ban_key_sc.set("")
            if hasattr(self, "ban_multi_combo"):
                self.ban_multi_combo.clear_selection()
        except Exception:
            pass

        # تصفير صفحة الأكواد العامة (إنشاء)
        try:
            for attr in ("general_create_key_entry", "general_create_note_entry",
                         "general_create_count_entry", "general_create_maxdevices_entry",
                         "general_create_amount_entry"):
                if hasattr(self, attr):
                    getattr(self, attr).delete(0, "end")
            if hasattr(self, "general_create_permissions_sc"):
                self.general_create_permissions_sc.set("all")
            if hasattr(self, "general_create_type_entry"):
                self.general_create_type_entry.delete(0, "end")
                self.general_create_type_entry.insert(0, "general")
            if hasattr(self, "general_create_duration_sc"):
                self.general_create_duration_sc.set("")
            if hasattr(self, "general_create_enabled"):
                self.general_create_enabled.select()
        except Exception:
            pass

        # تصفير صفحة الأكواد العامة (تعديل + إدارة الأجهزة)
        try:
            for attr in ("general_edit_key_entry", "general_edit_note_entry",
                         "general_edit_maxdevices_entry", "general_edit_amount_entry"):
                if hasattr(self, attr):
                    getattr(self, attr).delete(0, "end")
            if hasattr(self, "general_edit_type_entry"):
                self.general_edit_type_entry.delete(0, "end")
            if hasattr(self, "general_edit_duration_sc"):
                self.general_edit_duration_sc.set("")
            if hasattr(self, "general_edit_permissions_sc"):
                self.general_edit_permissions_sc.set("")
            if hasattr(self, "general_edit_enabled"):
                self.general_edit_enabled.deselect()
            if hasattr(self, "general_edit_key_sc"):
                self.general_edit_key_sc.set("")
            if hasattr(self, "general_edit_device_sc"):
                self.general_edit_device_sc.set_values([])
                self.general_edit_device_sc.set("")
            if hasattr(self, "general_edit_devices_count_label"):
                self.general_edit_devices_count_label.configure(text="الأجهزة المسجلة: -- / --")
        except Exception:
            pass

        # تصفير صفحة الأكواد العامة (حذف)
        try:
            if hasattr(self, "general_delete_key_sc"):
                self.general_delete_key_sc.set("")
        except Exception:
            pass

        self.refresh()
        self._show_page(current_page)
        messagebox.showinfo("نجاح", "تمت إعادة تهيئة البيانات والواجهة بنجاح")

    def _close_all_dropdowns(self):
        # البحث عن كل الـ SearchableCombo في التطبيق وإغلاق قوائمها
        def _close_rec(w):
            if isinstance(w, SearchableCombo):
                w._close_dropdown()
            try:
                for child in w.winfo_children():
                    _close_rec(child)
            except Exception:
                pass
        _close_rec(self)

    def _card(self, parent, title=None):
        f = ctk.CTkFrame(parent, fg_color=CARD, corner_radius=12)
        f.pack(fill="x", pady=8, padx=4)
        inner = ctk.CTkFrame(f, fg_color="transparent")
        inner.pack(fill="x", padx=20, pady=16)
        if title:
            ctk.CTkLabel(
                inner, text=title,
                font=("Segoe UI", 14, "bold"), text_color=ACCENT, anchor="e"
            ).pack(anchor="e", pady=(0, 10))
        return inner

    def _section_separator(self, parent, text):
        f = ctk.CTkFrame(parent, fg_color="transparent")
        f.pack(fill="x", pady=(30, 20))
        ctk.CTkFrame(f, height=1, fg_color=BORDER).pack(side="right", fill="x", expand=True)
        ctk.CTkLabel(f, text=f"  {text}  ", font=("Segoe UI", 18, "bold"), text_color=TEXT_DIM).pack(side="right")
        ctk.CTkFrame(f, height=1, fg_color=BORDER).pack(side="right", fill="x", expand=True)

    def _generate_unique_key_names(self, base_name, count, existing_keys):
        generated = []
        for _ in range(count):
            while True:
                suffix = "".join(random.choices(string.ascii_uppercase + string.digits, k=6))
                candidate = f"{base_name}-{suffix}"
                if candidate not in existing_keys and candidate not in generated:
                    generated.append(candidate)
                    break
        return generated

    # ── Duration row ──────────────────────────────────────────────────────────
    def _duration_row(self, parent, sc_attr, amount_attr):
        row = ctk.CTkFrame(parent, fg_color="transparent")
        row.pack(fill="x", pady=(0, 4))

        left = ctk.CTkFrame(row, fg_color="transparent")
        left.pack(side="right", fill="x", expand=True, padx=(4, 0))
        label(left, "نوع المدة", small=True).pack(anchor="e")
        sc = SearchableCombo(left, values=list(self.duration_map.keys()), placeholder="نوع المدة")
        sc.pack(fill="x")
        sc.set("")
        setattr(self, sc_attr, sc)

        right = ctk.CTkFrame(row, fg_color="transparent")
        right.pack(side="right", fill="x", expand=True, padx=(0, 4))
        label(right, "العدد", small=True).pack(anchor="e")
        a = field(right, "مثال: 30")
        a.pack(fill="x")
        setattr(self, amount_attr, a)

    # ═════════════════════════════════════════════════════════════════════════
    #  CREATE page
    # ═════════════════════════════════════════════════════════════════════════
    def _build_create_page(self, page):
        ctk.CTkLabel(
            page, text="إنشاء كود جديد",
            font=("Segoe UI", 20, "bold"), text_color=TEXT, anchor="e",
        ).pack(anchor="e", pady=(8, 16))

        c = self._card(page, "المعلومات الأساسية")
        self.create_key_entry     = labeled_field(c, "اسم الكود *", "مثال: USER-ABC-123")
        self.create_comment_entry = labeled_field(c, "التعليق",     "ملاحظة اختيارية")
        self.create_count_entry   = labeled_field(
            c, "عدد الأكواد (اختياري)",
            "اتركه فارغًا أو 1 لكود واحد بنفس الاسم"
        )

        d = self._card(page, "المدة")
        self._duration_row(d, "create_duration_sc", "create_amount_entry")

        v = self._card(page, "تقييد الجهاز (اختياري)")
        self.create_hwid_entry = labeled_field(v, "HWID",        "Hardware ID")
        self.create_mac_entry  = labeled_field(v, "MAC Address", "XX:XX:XX:XX:XX:XX")

        act = self._card(page)
        row = ctk.CTkFrame(act, fg_color="transparent")
        row.pack(fill="x")

        self.create_enabled = ctk.CTkSwitch(
            row, text="  مفعّل",
            font=("Segoe UI", 13), text_color=TEXT,
            progress_color=SUCCESS, button_color=TEXT,
        )
        self.create_enabled.select()
        self.create_enabled.pack(side="right")

        btn(act, "➕ إنشاء الكود", self.create_key, width=200).pack(anchor="center", pady=(12, 0))

    # ═════════════════════════════════════════════════════════════════════════
    #  EDIT page
    # ═════════════════════════════════════════════════════════════════════════
    def _build_edit_page(self, page):
        ctk.CTkLabel(
            page, text="تعديل كود",
            font=("Segoe UI", 20, "bold"), text_color=TEXT, anchor="e",
        ).pack(anchor="e", pady=(8, 16))

        s = self._card(page, "اختيار الكود")
        label(s, "الكود", small=True).pack(anchor="e")
        self.edit_key_sc = SearchableCombo(s, placeholder="ابحث عن كود...")
        self.edit_key_sc.pack(fill="x", pady=(0, 8))
        btn(s, "📂 تحميل البيانات", self.load_selected_key, width=200).pack(anchor="center")

        c = self._card(page, "المعلومات الأساسية")
        self.edit_key_name      = labeled_field(c, "اسم الكود *", "")
        self.edit_comment_entry = labeled_field(c, "التعليق",     "")

        d = self._card(page, "المدة")
        self._duration_row(d, "edit_duration_sc", "edit_amount_entry")

        a = self._card(page, "بيانات التفعيل")
        self.edit_activation_entry = labeled_field(a, "تاريخ التفعيل",  "activationDate")
        self.edit_expiry_entry     = labeled_field(a, "تاريخ الانتهاء", "expiryDate")

        v = self._card(page, "تقييد الجهاز")
        self.edit_hwid_entry = labeled_field(v, "HWID",        "")
        self.edit_mac_entry  = labeled_field(v, "MAC Address", "")

        act = self._card(page)
        row = ctk.CTkFrame(act, fg_color="transparent")
        row.pack(fill="x", pady=(0, 12))

        self.edit_enabled = ctk.CTkSwitch(
            row, text="  مفعّل",
            font=("Segoe UI", 13), text_color=TEXT,
            progress_color=SUCCESS, button_color=TEXT,
        )
        self.edit_enabled.pack(side="right")

        btns_row = ctk.CTkFrame(act, fg_color="transparent")
        btns_row.pack(anchor="center")

        btn(btns_row, "💾 حفظ التعديلات", self.save_edited_key, width=180).pack(side="right", padx=6)
        btn(
            btns_row, "🔁 تصفير التفعيل",
            self.reset_activation_data,
            color=DANGER, hover=DANGER_HOV, width=180,
        ).pack(side="right", padx=6)

    # ═════════════════════════════════════════════════════════════════════════
    #  DELETE page
    # ═════════════════════════════════════════════════════════════════════════
    def _build_delete_page(self, page):
        ctk.CTkLabel(
            page, text="حذف كود",
            font=("Segoe UI", 20, "bold"), text_color=TEXT, anchor="e",
        ).pack(anchor="e", pady=(8, 16))

        c = self._card(page, "اختيار الكود للحذف")
        label(c, "الكود", small=True).pack(anchor="e")
        self.delete_key_sc = SearchableCombo(c, placeholder="ابحث عن كود...")
        self.delete_key_sc.pack(fill="x", pady=(0, 12))

        ctk.CTkLabel(
            c, text="⚠️ سيتم حذف الكود بشكل نهائي",
            font=("Segoe UI", 12), text_color=DANGER, anchor="e",
        ).pack(anchor="e", pady=(0, 8))

        btn(c, "🗑 حذف الكود", self.delete_selected_key,
            color=DANGER, hover=DANGER_HOV, width=200).pack(anchor="center")

        # ── حذف عدة أكواد دفعة واحدة ──────────────────────────────────────
        ctk.CTkFrame(page, height=1, fg_color=BORDER).pack(fill="x", padx=4, pady=(8, 0))

        mc = self._card(page, "حذف عدة أكواد دفعة واحدة")
        ctk.CTkLabel(
            mc, text="ابحث واضغط على الأكواد المطلوبة لتحديدها (تقدر تختار أكتر من كود)",
            font=("Segoe UI", 12), text_color=TEXT_DIM, anchor="e",
        ).pack(anchor="e", pady=(0, 6))
        self.delete_multi_combo = MultiSelectCombo(mc, placeholder="ابحث عن كود...")
        self.delete_multi_combo.pack(fill="x", pady=(0, 8))

        btns_row_del = ctk.CTkFrame(mc, fg_color="transparent")
        btns_row_del.pack(anchor="center", pady=(8, 0))
        btn(btns_row_del, "🗑 حذف الأكواد المتعددة", self.delete_multiple_keys,
            color=DANGER, hover=DANGER_HOV, width=220).pack(side="right", padx=6)
        btn(btns_row_del, "✖️ إلغاء التحديد", self.delete_multi_combo.clear_selection,
            color=CARD2, hover="#2e3360", width=160).pack(side="right", padx=6)

        # ── حذف الأكواد المنتهية الصلاحية ───────────────────────────────
        ctk.CTkFrame(page, height=1, fg_color=BORDER).pack(fill="x", padx=4, pady=(8, 0))

        exp_c = self._card(page, "تنظيف الأكواد المنتهية")
        ctk.CTkLabel(
            exp_c, text="هيتم حذف كل الأكواد اللي تاريخ انتهائها فات نهائيًا",
            font=("Segoe UI", 12), text_color=TEXT_DIM, anchor="e",
        ).pack(anchor="e", pady=(0, 8))

        btn(exp_c, "🧹 حذف الأكواد المنتهية", self.delete_expired_keys,
            color=DANGER, hover=DANGER_HOV, width=220).pack(anchor="center")

    # ═════════════════════════════════════════════════════════════════════════
    #  BAN page
    # ═════════════════════════════════════════════════════════════════════════
    def _build_ban_page(self, page):
        ctk.CTkLabel(
            page, text="بان الجهاز",
            font=("Segoe UI", 20, "bold"), text_color=TEXT, anchor="e",
        ).pack(anchor="e", pady=(8, 16))

        s = self._card(page, "اختيار كود لجلب بيانات الجهاز")
        label(s, "ابحث عن كود", small=True).pack(anchor="e")
        self.ban_key_sc = SearchableCombo(s, placeholder="اكتب لتصفية الأكواد...")
        self.ban_key_sc.pack(fill="x", pady=(0, 8))
        self.ban_key_sc.bind_select(lambda v: ())
        btn(s, "📂 جلب بيانات الجهاز", self._load_ban_key_data, width=200).pack(anchor="center")

        d = self._card(page, "بيانات الجهاز")
        self.ban_hwid_entry = labeled_field(d, "HWID",        "سيُملأ تلقائياً")
        self.ban_mac_entry  = labeled_field(d, "MAC Address", "سيُملأ تلقائياً")

        r = self._card(page, "تفاصيل البان")
        self.ban_reason_entry = labeled_field(r, "السبب", "مثال: Cheating")

        bd = self._card(page, "مدة البان")
        self._duration_row(bd, "ban_duration_sc", "ban_amount_entry")

        default_ban_at = datetime.now().strftime("%Y-%m-%d %I:%M:%S %p")
        label(r, "تاريخ البان", small=True).pack(anchor="e", pady=(6, 1))
        self.ban_date_entry = field(r, default_ban_at)
        self.ban_date_entry.pack(fill="x")
        self.ban_date_entry.insert(0, default_ban_at)

        act = self._card(page)
        btns_row = ctk.CTkFrame(act, fg_color="transparent")
        btns_row.pack(anchor="center")

        btn(btns_row, "🚫 تنفيذ البان", self._do_ban,
            color=DANGER, hover=DANGER_HOV, width=180).pack(side="right", padx=6)
        btn(btns_row, "✅ رفع البان", self._do_unban,
            color=WARNING, hover=WARNING_HOV, width=180).pack(side="right", padx=6)

        # ── بان عدة أجهزة دفعة واحدة ──────────────────────────────────────
        ctk.CTkFrame(page, height=1, fg_color=BORDER).pack(fill="x", padx=4, pady=(8, 0))

        mb = self._card(page, "بان عدة أجهزة دفعة واحدة")
        ctk.CTkLabel(
            mb, text="ابحث واضغط على الأكواد المطلوبة لتحديدها (تقدر تختار أكتر من كود)، وسيتم استخدام HWID و MAC الخاصين بكل كود",
            font=("Segoe UI", 12), text_color=TEXT_DIM, anchor="e",
        ).pack(anchor="e", pady=(0, 6))
        self.ban_multi_combo = MultiSelectCombo(mb, placeholder="ابحث عن كود...")
        self.ban_multi_combo.pack(fill="x", pady=(0, 8))

        ctk.CTkLabel(
            mb, text="السبب وتاريخ البان ومدة البان هياخدوا نفس القيم المكتوبة في كارتي \"تفاصيل البان\" و\"مدة البان\" أعلاه",
            font=("Segoe UI", 11), text_color=TEXT_DIM, anchor="e",
        ).pack(anchor="e", pady=(0, 8))

        btns_m = ctk.CTkFrame(mb, fg_color="transparent")
        btns_m.pack(anchor="center")
        btn(btns_m, "🚫 بان الكل", self._do_ban_multi,
            color=DANGER, hover=DANGER_HOV, width=180).pack(side="right", padx=6)
        btn(btns_m, "✅ رفع البان عن الكل", self._do_unban_multi,
            color=WARNING, hover=WARNING_HOV, width=180).pack(side="right", padx=6)
        btn(btns_m, "✖️ إلغاء التحديد", self.ban_multi_combo.clear_selection,
            color=CARD2, hover="#2e3360", width=160).pack(side="right", padx=6)

    # ═════════════════════════════════════════════════════════════════════════
    #  GENERAL KEYS page
    # ═════════════════════════════════════════════════════════════════════════
    def _build_general_page(self, page):
        ctk.CTkLabel(
            page, text="الأكواد العامة",
            font=("Segoe UI", 20, "bold"), text_color=TEXT, anchor="e",
        ).pack(anchor="e", pady=(8, 16))

        # ── إنشاء كود عام ────────────────────────────────────────────────
        c = self._card(page, "إنشاء كود عام جديد")

        self.general_create_key_entry  = labeled_field(c, "اسم الكود *",  "مثال: PANDA-LIFE-XXXX")
        self.general_create_note_entry = labeled_field(c, "ملاحظة",       "مثال: كود عام مدى الحياة")
        self.general_create_count_entry = labeled_field(
            c, "عدد الأكواد (اختياري)",
            "اتركه فارغًا أو 1 لكود واحد بنفس الاسم"
        )
        self.general_create_maxdevices_entry = labeled_field(
            c, "الحد الأقصى للأجهزة",
            "اتركه فارغًا لجهاز واحد، أو أدخل رقم (مثال: 10)"
        )

        label(c, "الصلاحيات", small=True).pack(anchor="e")
        self.general_create_permissions_sc = SearchableCombo(c, values=["all", "limited"], placeholder="اختر الصلاحية")
        self.general_create_permissions_sc.pack(fill="x", pady=(0, 8))
        self.general_create_permissions_sc.set("")

        self.general_create_type_entry = field(c, "general")
        self.general_create_type_entry.insert(0, "general")

        d = self._card(page, "المدة")
        self._duration_row(d, "general_create_duration_sc", "general_create_amount_entry")

        act_c = self._card(page)
        row_c = ctk.CTkFrame(act_c, fg_color="transparent")
        row_c.pack(fill="x", pady=(0, 12))

        self.general_create_enabled = ctk.CTkSwitch(
            row_c, text="  مفعّل",
            font=("Segoe UI", 13), text_color=TEXT,
            progress_color=SUCCESS, button_color=TEXT,
        )
        self.general_create_enabled.select()
        self.general_create_enabled.pack(side="right")

        btn(act_c, "➕ إنشاء الكود العام", self._general_create_key, width=220).pack(
            anchor="center", pady=(0, 0)
        )

        # ── تعديل كود عام ────────────────────────────────────────────────
        self._section_separator(page, "✏️ تعديل كود عام")

        e = self._card(page, "تعديل كود عام")

        label(e, "الكود", small=True).pack(anchor="e")
        self.general_edit_key_sc = SearchableCombo(e, placeholder="ابحث عن كود...")
        self.general_edit_key_sc.pack(fill="x", pady=(0, 8))
        btn(e, "📂 تحميل البيانات", self._general_load_key, width=200).pack(anchor="center")

        self.general_edit_key_entry  = labeled_field(e, "اسم الكود *",  "")
        self.general_edit_note_entry = labeled_field(e, "ملاحظة",       "")
        self.general_edit_maxdevices_entry = labeled_field(e, "الحد الأقصى للأجهزة", "")

        label(e, "الصلاحيات", small=True).pack(anchor="e")
        self.general_edit_permissions_sc = SearchableCombo(e, values=["all", "limited"], placeholder="اختر الصلاحية")
        self.general_edit_permissions_sc.pack(fill="x", pady=(0, 8))

        self.general_edit_type_entry = field(e, "general")

        d2 = self._card(page, "المدة")
        self._duration_row(d2, "general_edit_duration_sc", "general_edit_amount_entry")

        # ── إدارة الأجهزة المسجلة على الكود ─────────────────────────────
        dev_c = self._card(page, "الأجهزة المسجلة على الكود")

        self.general_edit_devices_count_label = ctk.CTkLabel(
            dev_c, text="الأجهزة المسجلة: -- / --",
            font=("Segoe UI", 12), text_color=TEXT_DIM, anchor="e",
        )
        self.general_edit_devices_count_label.pack(anchor="e", pady=(0, 8))

        label(dev_c, "اختر جهازًا لحذفه (تحرير مكانه)", small=True).pack(anchor="e")
        self.general_edit_device_sc = SearchableCombo(dev_c, placeholder="اختر جهازًا...")
        self.general_edit_device_sc.pack(fill="x", pady=(0, 10))

        btn(dev_c, "🗑 حذف الجهاز المحدد", self._general_delete_device,
            color=DANGER, hover=DANGER_HOV, width=220).pack(anchor="center")

        act_e = self._card(page)
        row_e = ctk.CTkFrame(act_e, fg_color="transparent")
        row_e.pack(fill="x", pady=(0, 12))

        self.general_edit_enabled = ctk.CTkSwitch(
            row_e, text="  مفعّل",
            font=("Segoe UI", 13), text_color=TEXT,
            progress_color=SUCCESS, button_color=TEXT,
        )
        self.general_edit_enabled.pack(side="right")

        btn(act_e, "💾 حفظ التعديلات", self._general_save_key, width=200).pack(anchor="center")

        # ── حذف كود عام ──────────────────────────────────────────────────
        self._section_separator(page, "🗑 حذف كود عام")

        del_c = self._card(page, "حذف كود عام")

        label(del_c, "الكود", small=True).pack(anchor="e")
        self.general_delete_key_sc = SearchableCombo(del_c, placeholder="ابحث عن كود عام...")
        self.general_delete_key_sc.pack(fill="x", pady=(0, 12))

        ctk.CTkLabel(
            del_c, text="⚠️ سيتم حذف الكود بشكل نهائي",
            font=("Segoe UI", 12), text_color=DANGER, anchor="e",
        ).pack(anchor="e", pady=(0, 8))

        btn(del_c, "🗑 حذف الكود العام", self._general_delete_key,
            color=DANGER, hover=DANGER_HOV, width=220).pack(anchor="center")

        # ── تنظيف الأجهزة المنتهية الصلاحية ──────────────────────────────
        self._section_separator(page, "🧹 تنظيف الأجهزة المنتهية")

        exp_gc = self._card(page, "تنظيف الأجهزة المنتهية في الأكواد العامة")
        ctk.CTkLabel(
            exp_gc, text="هيتم حذف كل الأجهزة اللي تاريخ انتهائها فات من كل الأكواد العامة\n(الجهاز بيتحذف من الكود بس، والكود نفسه يفضل موجود ومكانه يتحرر لجهاز جديد)",
            font=("Segoe UI", 12), text_color=TEXT_DIM, anchor="e", justify="right",
        ).pack(anchor="e", pady=(0, 8))

        btn(exp_gc, "🧹 حذف الأجهزة المنتهية", self.delete_expired_general_devices,
            color=DANGER, hover=DANGER_HOV, width=240).pack(anchor="center")

    # ═════════════════════════════════════════════════════════════════════════
    #  General keys logic
    # ═════════════════════════════════════════════════════════════════════════
    def _general_create_key(self):
        try:
            key_name = self.general_create_key_entry.get().strip()
            if not key_name:
                messagebox.showerror("خطأ", "اسم الكود مطلوب")
                return

            count_text = self.general_create_count_entry.get().strip()
            try:
                count = int(count_text) if count_text else 1
            except ValueError:
                count = 1
            if count < 1:
                count = 1

            key_type      = self.general_create_type_entry.get().strip() or "general"
            permissions   = self.general_create_permissions_sc.get().strip() or "all"
            note          = self.general_create_note_entry.get().strip()
            enabled       = "yes" if self.general_create_enabled.get() else "no"
            duration_type = self.general_create_duration_sc.get()

            maxdevices_text = self.general_create_maxdevices_entry.get().strip()
            try:
                max_devices = int(maxdevices_text) if maxdevices_text else 1
            except ValueError:
                messagebox.showerror("خطأ", "الحد الأقصى للأجهزة يجب أن يكون رقمًا صحيحًا")
                return
            if max_devices < 1:
                max_devices = 1

            duration_kv = {}
            if duration_type == "مدى الحياة":
                duration_kv["durationDays"] = -1
            else:
                amount_text = self.general_create_amount_entry.get().strip()
                if not amount_text:
                    messagebox.showerror("خطأ", "عدد المدة مطلوب")
                    return
                duration_kv[self.duration_map[duration_type]] = int(amount_text)

            existing_keys = {i.get("key") for i in self.general_keys_data}

            if count == 1:
                if key_name in existing_keys:
                    messagebox.showerror("خطأ", "الكود موجود بالفعل")
                    return
                new_keys = [key_name]
            else:
                new_keys = self._generate_unique_key_names(key_name, count, existing_keys)

            for kname in new_keys:
                new_item = {
                    "key":         kname,
                    "type":        key_type,
                    "permissions": permissions,
                    "enabled":     enabled,
                    "maxDevices":  max_devices,
                }
                new_item.update(duration_kv)
                if note:
                    new_item["note"] = note
                new_item["devices"] = []
                self.general_keys_data.append(new_item)

            self._save_general_keys("Created General Key")

            if count == 1:
                messagebox.showinfo("نجاح ✅", f'تم إنشاء الكود العام "{new_keys[0]}"')
            else:
                names = "\n".join(f"- {k}" for k in new_keys)
                messagebox.showinfo("نجاح ✅", f"تم إنشاء {count} كود عام:\n{names}")

            for w in (self.general_create_key_entry, self.general_create_note_entry,
                      self.general_create_amount_entry, self.general_create_count_entry,
                      self.general_create_maxdevices_entry):
                w.delete(0, "end")
            self.general_create_duration_sc.set("")
            self.general_create_permissions_sc.set("")
            self.general_create_enabled.select()
            self.general_create_type_entry.delete(0, "end")
            self.general_create_type_entry.insert(0, "general")
            self._refresh_general()

        except ValueError:
            messagebox.showerror("خطأ", "عدد المدة يجب أن يكون رقمًا")
        except Exception as e:
            messagebox.showerror("خطأ", str(e))

    def _general_load_key(self):
        selected = self.general_edit_key_sc.get().strip()
        self.selected_general_key_data = next(
            (i for i in self.general_keys_data if i.get("key") == selected), None
        )
        if not self.selected_general_key_data:
            messagebox.showwarning("تنبيه", "اختر كوداً أولاً")
            return

        data = self.selected_general_key_data

        self.general_edit_key_entry.delete(0, "end")
        self.general_edit_key_entry.insert(0, data.get("key", ""))

        self.general_edit_note_entry.delete(0, "end")
        self.general_edit_note_entry.insert(0, data.get("note", ""))

        self.general_edit_type_entry.delete(0, "end")
        self.general_edit_type_entry.insert(0, data.get("type", "general"))

        self.general_edit_maxdevices_entry.delete(0, "end")
        self.general_edit_maxdevices_entry.insert(0, str(data.get("maxDevices", 1)))

        self.general_edit_permissions_sc.set(data.get("permissions", "all"))

        # تحديد نوع المدة والعدد
        duration_type, duration_value = "يوم", ""
        for unit, fk in [
            ("ثانية", "durationSeconds"), ("دقيقة", "durationMinutes"),
            ("ساعة",  "durationHours"),   ("أسبوع", "durationWeeks"),
            ("شهر",   "durationMonths"),
            ("سنة",   "durationYears"),
        ]:
            if fk in data:
                duration_type, duration_value = unit, data[fk]
                break
        else:
            if data.get("durationDays") == -1:
                duration_type = "مدى الحياة"
            elif "durationDays" in data:
                duration_type, duration_value = "يوم", data["durationDays"]

        self.general_edit_duration_sc.set(duration_type)
        self.general_edit_amount_entry.delete(0, "end")
        if duration_value != "":
            self.general_edit_amount_entry.insert(0, str(duration_value))

        if data.get("enabled") == "yes":
            self.general_edit_enabled.select()
        else:
            self.general_edit_enabled.deselect()

        self._general_refresh_devices_ui()

    def _general_save_key(self):
        if not self.selected_general_key_data:
            messagebox.showwarning("تنبيه", "حمّل كوداً أولاً")
            return
        try:
            item = self.selected_general_key_data
            item["key"]         = self.general_edit_key_entry.get().strip()
            item["type"]        = self.general_edit_type_entry.get().strip() or "general"
            item["permissions"] = self.general_edit_permissions_sc.get().strip() or "all"
            item["enabled"]     = "yes" if self.general_edit_enabled.get() else "no"

            maxdevices_text = self.general_edit_maxdevices_entry.get().strip()
            try:
                max_devices = int(maxdevices_text) if maxdevices_text else 1
            except ValueError:
                messagebox.showerror("خطأ", "الحد الأقصى للأجهزة يجب أن يكون رقمًا صحيحًا")
                return
            if max_devices < 1:
                max_devices = 1
            item["maxDevices"] = max_devices

            if not isinstance(item.get("devices"), list):
                item["devices"] = []

            note = self.general_edit_note_entry.get().strip()
            if note:
                item["note"] = note
            else:
                item.pop("note", None)

            for k in ["durationSeconds", "durationMinutes", "durationHours",
                      "durationDays", "durationWeeks", "durationMonths", "durationYears"]:
                item.pop(k, None)

            duration_type = self.general_edit_duration_sc.get()
            if duration_type == "مدى الحياة":
                item["durationDays"] = -1
            else:
                item[self.duration_map[duration_type]] = int(
                    self.general_edit_amount_entry.get().strip()
                )

            key_name_after_save = item.get("key")
            self._save_general_keys("Edited General Key")
            self._refresh_general()
            self.selected_general_key_data = next(
                (i for i in self.general_keys_data if i.get("key") == key_name_after_save), None
            )
            self._general_refresh_devices_ui()
            messagebox.showinfo("نجاح ✅", "تم حفظ التعديلات")

        except ValueError:
            messagebox.showerror("خطأ", "عدد المدة يجب أن يكون رقمًا")
        except Exception as e:
            messagebox.showerror("خطأ", str(e))

    def _general_delete_key(self):
        selected = self.general_delete_key_sc.get().strip()
        if not selected:
            messagebox.showwarning("تنبيه", "اختر كوداً أولاً")
            return
        if not messagebox.askyesno("تأكيد الحذف ⚠️", f'هتحذف الكود "{selected}". متأكد؟'):
            return
        self.general_keys_data = [
            i for i in self.general_keys_data if i.get("key") != selected
        ]
        if self.selected_general_key_data and self.selected_general_key_data.get("key") == selected:
            self.selected_general_key_data = None
            if hasattr(self, "general_edit_device_sc"):
                self.general_edit_device_sc.set_values([])
                self.general_edit_device_sc.set("")
                self.general_edit_devices_count_label.configure(text="الأجهزة المسجلة: -- / --")
        self._save_general_keys("Deleted General Key")
        self._refresh_general()
        messagebox.showinfo("نجاح ✅", f'تم حذف الكود "{selected}"')

    def _save_general_keys(self, msg="Update General Keys"):
        path = SECRET_CONFIG.get("GENERAL_KEYS_FILE_PATH", "GENERAL_KEYS.json")
        self.general_keys_sha = self.gm.save_json(
            path, self.general_keys_data, self.general_keys_sha, msg
        )

    def _refresh_general(self):
        try:
            path = SECRET_CONFIG.get("GENERAL_KEYS_FILE_PATH", "GENERAL_KEYS.json")
            self.general_keys_data, self.general_keys_sha = self.gm.get_json(path)
            if not isinstance(self.general_keys_data, list):
                self.general_keys_data = []
            keys_list = [i.get("key", "") for i in self.general_keys_data]
            self.general_count_label.configure(text=f"العامة: {len(self.general_keys_data)}")
            for sc_attr in ("general_edit_key_sc", "general_delete_key_sc"):
                if hasattr(self, sc_attr):
                    getattr(self, sc_attr).set_values(keys_list)
        except Exception as e:
            messagebox.showerror("خطأ", str(e))

    # ── إدارة الأجهزة المسجلة على الكود العام ───────────────────────────────
    def _format_general_device(self, idx, dev):
        hwid = (dev.get("hwid") or "").strip()
        short_hwid = (hwid[:14] + "…") if len(hwid) > 14 else (hwid or "-")
        mac    = dev.get("macAddress") or "-"
        expiry = dev.get("expiryDate") or "-"
        return f"{idx}) HWID: {short_hwid} | MAC: {mac} | ينتهي: {expiry}"

    def _general_refresh_devices_ui(self):
        if not hasattr(self, "general_edit_device_sc"):
            return
        data = self.selected_general_key_data or {}
        devices = data.get("devices")
        devices = devices if isinstance(devices, list) else []

        self._general_device_map = {}
        display_list = []
        for idx, dev in enumerate(devices, start=1):
            disp = self._format_general_device(idx, dev)
            display_list.append(disp)
            self._general_device_map[disp] = dev

        self.general_edit_device_sc.set_values(display_list)
        self.general_edit_device_sc.set("")

        max_dev = data.get("maxDevices", 1)
        self.general_edit_devices_count_label.configure(
            text=f"الأجهزة المسجلة: {len(devices)} / {max_dev}"
        )

    def _general_delete_device(self):
        if not self.selected_general_key_data:
            messagebox.showwarning("تنبيه", "حمّل كوداً أولاً")
            return

        selected_disp = self.general_edit_device_sc.get().strip()
        dev = self._general_device_map.get(selected_disp)
        if not dev:
            messagebox.showwarning("تنبيه", "اختر جهازًا من القائمة أولاً")
            return

        hwid = dev.get("hwid", "-")
        if not messagebox.askyesno(
            "تأكيد الحذف ⚠️",
            f"هتحذف الجهاز ده من الكود عشان يتحرر مكانه؟\nHWID: {hwid}",
        ):
            return

        devices = self.selected_general_key_data.get("devices", [])
        self.selected_general_key_data["devices"] = [d for d in devices if d is not dev]
        key_name = self.selected_general_key_data.get("key")

        self._save_general_keys("Removed device from general key")
        self._refresh_general()
        self.selected_general_key_data = next(
            (i for i in self.general_keys_data if i.get("key") == key_name), None
        )
        self._general_refresh_devices_ui()
        messagebox.showinfo("نجاح ✅", "تم حذف الجهاز وتحرير مكانه")

    def delete_expired_general_devices(self):
        today = date.today()
        total_removed = 0
        affected = []

        for item in self.general_keys_data:
            devices = item.get("devices")
            if not isinstance(devices, list) or not devices:
                continue

            kept, removed_here = [], 0
            for dev in devices:
                exp = dev.get("expiryDate")
                if not exp:
                    kept.append(dev)
                    continue
                try:
                    exp_date = date.fromisoformat(str(exp)[:10])
                except Exception:
                    kept.append(dev)
                    continue
                if exp_date < today:
                    removed_here += 1
                else:
                    kept.append(dev)

            if removed_here:
                item["devices"] = kept
                total_removed += removed_here
                affected.append((item.get("key", ""), removed_here))

        if total_removed == 0:
            messagebox.showinfo("معلومة", "لا يوجد أجهزة منتهية الصلاحية في الأكواد العامة حاليًا")
            return

        lines = "\n".join(f"- {k}: {n} جهاز" for k, n in affected)
        if not messagebox.askyesno(
            "تأكيد الحذف ⚠️",
            f"سيتم حذف {total_removed} جهاز منتهي الصلاحية من الأكواد العامة:\n{lines}\nمتأكد؟",
        ):
            return

        selected_key_name = (
            self.selected_general_key_data.get("key") if self.selected_general_key_data else None
        )
        self._save_general_keys("Deleted expired devices from general keys")
        self._refresh_general()
        if selected_key_name:
            self.selected_general_key_data = next(
                (i for i in self.general_keys_data if i.get("key") == selected_key_name), None
            )
            self._general_refresh_devices_ui()
        messagebox.showinfo("نجاح ✅", f"تم حذف {total_removed} جهاز منتهي الصلاحية")

    # ═════════════════════════════════════════════════════════════════════════
    #  Ban helpers
    # ═════════════════════════════════════════════════════════════════════════
    def _load_ban_key_data(self):
        selected = self.ban_key_sc.get().strip()
        if not selected:
            messagebox.showwarning("تنبيه", "اختر كوداً أولاً")
            return
        key_item = next((i for i in self.keys_data if i.get("key") == selected), None)
        if not key_item:
            messagebox.showwarning("تنبيه", "الكود غير موجود")
            return
        hwid = key_item.get("hwid", "")
        mac  = key_item.get("macAddress", "")
        self.ban_hwid_entry.delete(0, "end")
        self.ban_mac_entry.delete(0, "end")
        if hwid: self.ban_hwid_entry.insert(0, hwid)
        if mac:  self.ban_mac_entry.insert(0, mac)
        if not hwid and not mac:
            messagebox.showinfo("معلومة", "الكود لا يحتوي على HWID أو MAC.\nيمكنك إدخالهم يدوياً.")

    def _get_ban_file(self):
        try:
            ban_path = SECRET_CONFIG.get("BAN_FILE_PATH", "BAN.json")
            data, sha = self.gm.get_json(ban_path)
            self.ban_data = data if isinstance(data, list) else []
            self.ban_sha  = sha
        except Exception:
            self.ban_data = []
            self.ban_sha  = None

    def _save_ban_file(self, msg="Update BAN"):
        ban_path = SECRET_CONFIG.get("BAN_FILE_PATH", "BAN.json")
        self.ban_sha = self.gm.save_json(ban_path, self.ban_data, self.ban_sha, msg)

    def _get_ban_duration_kv(self):
        """
        يرجع (duration_kv, ban_expiry, error_msg)
        duration_kv: dict زي durationDays/durationWeeks/... علشان تتحط في entry البان
        ban_expiry: "Permanent" لو مدى الحياة، وإلا None (برنامج تاني هو اللي بيحسبها)
        error_msg: نص الخطأ لو في مشكلة، وإلا None
        """
        duration_type = self.ban_duration_sc.get().strip()
        if not duration_type:
            return None, None, "اختار مدة البان أولاً"
        if duration_type not in self.duration_map:
            return None, None, "نوع مدة البان غير صحيح"

        if duration_type == "مدى الحياة":
            return {}, "Permanent", None

        amount_text = self.ban_amount_entry.get().strip()
        if not amount_text:
            return None, None, "عدد مدة البان مطلوب"
        try:
            amount = int(amount_text)
        except ValueError:
            return None, None, "عدد مدة البان يجب أن يكون رقمًا"

        return {self.duration_map[duration_type]: amount}, None, None

    def _do_ban(self):
        hwid   = self.ban_hwid_entry.get().strip()
        mac    = self.ban_mac_entry.get().strip()
        reason = self.ban_reason_entry.get().strip() or "unknown"
        ban_at = self.ban_date_entry.get().strip() or datetime.now().strftime("%Y-%m-%d %I:%M:%S %p")
        if not hwid and not mac:
            messagebox.showerror("خطأ", "لازم تدخل HWID أو MAC Address على الأقل")
            return

        duration_kv, ban_expiry, err = self._get_ban_duration_kv()
        if err:
            messagebox.showerror("خطأ", err)
            return

        if not messagebox.askyesno("تأكيد البان ⚠️", f"هتعمل بان للجهاز؟\nHWID: {hwid}\nMAC: {mac}"):
            return
        try:
            self._get_ban_file()
            found = False
            for entry in self.ban_data:
                if (hwid and entry.get("hwid") == hwid) or (mac and entry.get("macAddress") == mac):
                    for k in ["durationSeconds", "durationMinutes", "durationHours", "durationDays",
                              "durationWeeks", "durationMonths", "durationYears", "banExpiryDate"]:
                        entry.pop(k, None)
                    entry.update({"banned": "yes", "reason": reason, "bannedAt": ban_at, **duration_kv})
                    if ban_expiry: entry["banExpiryDate"] = ban_expiry
                    if hwid: entry["hwid"]       = hwid
                    if mac:  entry["macAddress"] = mac
                    found = True
                    break
            if not found:
                new_entry = {"banned": "yes", "reason": reason, "bannedAt": ban_at, **duration_kv}
                if ban_expiry: new_entry["banExpiryDate"] = ban_expiry
                if hwid: new_entry["hwid"]       = hwid
                if mac:  new_entry["macAddress"] = mac
                self.ban_data.append(new_entry)
            self._save_ban_file("Ban device")
            messagebox.showinfo("نجاح ✅", "تم تنفيذ البان بنجاح")
        except Exception as e:
            messagebox.showerror("خطأ", str(e))

    def _do_unban(self):
        hwid = self.ban_hwid_entry.get().strip()
        mac  = self.ban_mac_entry.get().strip()
        if not hwid and not mac:
            messagebox.showerror("خطأ", "لازم تدخل HWID أو MAC Address على الأقل")
            return
        if not messagebox.askyesno("تأكيد رفع البان", f"هترفع البان؟\nHWID: {hwid}\nMAC: {mac}"):
            return
        try:
            self._get_ban_file()
            found = False
            for entry in self.ban_data:
                if (hwid and entry.get("hwid") == hwid) or (mac and entry.get("macAddress") == mac):
                    entry["banned"] = "no"
                    for k in ["durationSeconds", "durationMinutes", "durationHours", "durationDays",
                              "durationWeeks", "durationMonths", "durationYears", "banExpiryDate"]:
                        entry.pop(k, None)
                    found = True
                    break
            if not found:
                messagebox.showwarning("تنبيه", "الجهاز مش موجود في قائمة البان")
                return
            self._save_ban_file("Unban device")
            messagebox.showinfo("نجاح ✅", "تم رفع البان بنجاح")
        except Exception as e:
            messagebox.showerror("خطأ", str(e))

    # ── بان/رفع بان أجهزة متعددة ─────────────────────────────────────────────
    def _parse_multi_devices(self):
        """يرجع لستة (key, hwid, mac) للأكواد المحددة في ban_multi_combo"""
        selected = self.ban_multi_combo.get_selected()
        devices = []
        for key in selected:
            item = next((i for i in self.keys_data if i.get("key") == key), None)
            if not item:
                continue
            hwid = (item.get("hwid") or "").strip()
            mac  = (item.get("macAddress") or "").strip()
            if hwid or mac:
                devices.append((key, hwid, mac))
        return devices

    def _do_ban_multi(self):
        selected = self.ban_multi_combo.get_selected()
        if not selected:
            messagebox.showwarning("تنبيه", "اختار أكواد للبان أولاً")
            return

        devices = self._parse_multi_devices()
        if not devices:
            messagebox.showwarning("تنبيه", "الأكواد المحددة لا تحتوي على HWID أو MAC")
            return

        reason = self.ban_reason_entry.get().strip() or "unknown"
        ban_at = self.ban_date_entry.get().strip() or datetime.now().strftime("%Y-%m-%d %I:%M:%S %p")

        duration_kv, ban_expiry, err = self._get_ban_duration_kv()
        if err:
            messagebox.showerror("خطأ", err)
            return

        lines = "\n".join(f"- {k} | HWID: {h or '-'} | MAC: {m or '-'}" for k, h, m in devices)
        if not messagebox.askyesno("تأكيد البان ⚠️", f"هتعمل بان لـ {len(devices)} جهاز:\n{lines}"):
            return

        try:
            self._get_ban_file()
            for key, hwid, mac in devices:
                found = False
                for entry in self.ban_data:
                    if (hwid and entry.get("hwid") == hwid) or (mac and entry.get("macAddress") == mac):
                        for k in ["durationSeconds", "durationMinutes", "durationHours", "durationDays",
                                  "durationWeeks", "durationMonths", "durationYears", "banExpiryDate"]:
                            entry.pop(k, None)
                        entry.update({"banned": "yes", "reason": reason, "bannedAt": ban_at, **duration_kv})
                        if ban_expiry: entry["banExpiryDate"] = ban_expiry
                        if hwid: entry["hwid"]       = hwid
                        if mac:  entry["macAddress"] = mac
                        found = True
                        break
                if not found:
                    new_entry = {"banned": "yes", "reason": reason, "bannedAt": ban_at, **duration_kv}
                    if ban_expiry: new_entry["banExpiryDate"] = ban_expiry
                    if hwid: new_entry["hwid"]       = hwid
                    if mac:  new_entry["macAddress"] = mac
                    self.ban_data.append(new_entry)

            self._save_ban_file("Ban multiple devices")
            self.ban_multi_combo.clear_selection()
            messagebox.showinfo("نجاح ✅", f"تم تنفيذ البان لـ {len(devices)} جهاز")
        except Exception as e:
            messagebox.showerror("خطأ", str(e))

    def _do_unban_multi(self):
        selected = self.ban_multi_combo.get_selected()
        if not selected:
            messagebox.showwarning("تنبيه", "اختار أكواد لرفع البان عنها أولاً")
            return

        devices = self._parse_multi_devices()
        if not devices:
            messagebox.showwarning("تنبيه", "الأكواد المحددة لا تحتوي على HWID أو MAC")
            return

        lines = "\n".join(f"- {k} | HWID: {h or '-'} | MAC: {m or '-'}" for k, h, m in devices)
        if not messagebox.askyesno("تأكيد رفع البان", f"هترفع البان عن {len(devices)} جهاز:\n{lines}"):
            return

        try:
            self._get_ban_file()
            not_found = []
            count = 0
            for key, hwid, mac in devices:
                found = False
                for entry in self.ban_data:
                    if (hwid and entry.get("hwid") == hwid) or (mac and entry.get("macAddress") == mac):
                        entry["banned"] = "no"
                        for k in ["durationSeconds", "durationMinutes", "durationHours", "durationDays",
                                  "durationWeeks", "durationMonths", "durationYears", "banExpiryDate"]:
                            entry.pop(k, None)
                        found = True
                        count += 1
                        break
                if not found:
                    not_found.append((key, hwid, mac))

            self._save_ban_file("Unban multiple devices")
            self.ban_multi_combo.clear_selection()

            msg = f"تم رفع البان عن {count} جهاز"
            if not_found:
                msg += "\n\nغير موجودين في قائمة البان:\n" + "\n".join(
                    f"- {k} | HWID: {h or '-'} | MAC: {m or '-'}" for k, h, m in not_found
                )
            messagebox.showinfo("نجاح ✅", msg)
        except Exception as e:
            messagebox.showerror("خطأ", str(e))


    # ═════════════════════════════════════════════════════════════════════════
    #  Refresh
    # ═════════════════════════════════════════════════════════════════════════
    def refresh(self):
        try:
            self.keys_data, self.current_sha = self.gm.get_json(
                SECRET_CONFIG["GITHUB_FILE_PATH"]
            )
            keys_list = [item.get("key", "") for item in self.keys_data]
            self.count_label.configure(text=f"الأكواد: {len(self.keys_data)}")
            for sc_attr in ("edit_key_sc", "delete_key_sc", "ban_key_sc", "delete_multi_combo", "ban_multi_combo", "general_edit_key_sc", "general_delete_key_sc"):
                if hasattr(self, sc_attr):
                    getattr(self, sc_attr).set_values(keys_list)
        except Exception as e:
            messagebox.showerror("خطأ", str(e))

        self._refresh_general()

    # ═════════════════════════════════════════════════════════════════════════
    #  Create key
    # ═════════════════════════════════════════════════════════════════════════
    def create_key(self):
        try:
            key_name = self.create_key_entry.get().strip()
            if not key_name:
                messagebox.showerror("خطأ", "اسم الكود مطلوب")
                return

            count_text = self.create_count_entry.get().strip()
            try:
                count = int(count_text) if count_text else 1
            except ValueError:
                count = 1
            if count < 1:
                count = 1

            duration_type = self.create_duration_sc.get()
            duration_kv = {}
            if duration_type == "مدى الحياة":
                duration_kv["durationDays"] = -1
            else:
                amount_text = self.create_amount_entry.get().strip()
                if not amount_text:
                    messagebox.showerror("خطأ", "عدد المدة مطلوب")
                    return
                duration_kv[self.duration_map[duration_type]] = int(amount_text)

            comment = self.create_comment_entry.get().strip()
            enabled = "yes" if self.create_enabled.get() else "no"
            hwid = self.create_hwid_entry.get().strip()
            mac  = self.create_mac_entry.get().strip()

            existing_keys = {i.get("key") for i in self.keys_data}

            if count == 1:
                if key_name in existing_keys:
                    messagebox.showerror("خطأ", "الكود موجود بالفعل")
                    return
                new_keys = [key_name]
            else:
                new_keys = self._generate_unique_key_names(key_name, count, existing_keys)

            for kname in new_keys:
                new_item = {
                    "key":     kname,
                    "comment": comment,
                    "enabled": enabled,
                    **duration_kv,
                }
                if hwid: new_item["hwid"]       = hwid
                if mac:  new_item["macAddress"] = mac
                self.keys_data.append(new_item)

            self.gm.save_json(SECRET_CONFIG["GITHUB_FILE_PATH"],
                              self.keys_data, self.current_sha, "Created Key")

            if count == 1:
                messagebox.showinfo("نجاح ✅", f'تم إنشاء الكود "{new_keys[0]}"')
            else:
                names = "\n".join(f"- {k}" for k in new_keys)
                messagebox.showinfo("نجاح ✅", f"تم إنشاء {count} كود:\n{names}")

            for w in (self.create_key_entry, self.create_amount_entry,
                      self.create_comment_entry, self.create_hwid_entry,
                      self.create_mac_entry, self.create_count_entry):
                w.delete(0, "end")
            self.create_duration_sc.set("")
            self.create_enabled.select()
            self.refresh()

        except ValueError:
            messagebox.showerror("خطأ", "عدد المدة يجب أن يكون رقمًا")
        except Exception as e:
            messagebox.showerror("خطأ", str(e))

    # ═════════════════════════════════════════════════════════════════════════
    #  Load / Save / Reset key  (Edit page)
    # ═════════════════════════════════════════════════════════════════════════
    def load_selected_key(self):
        selected = self.edit_key_sc.get()
        self.selected_key_data = next(
            (i for i in self.keys_data if i.get("key") == selected), None
        )
        if not self.selected_key_data:
            messagebox.showwarning("تنبيه", "اختر كوداً أولاً")
            return

        data = self.selected_key_data
        self.edit_key_name.delete(0, "end")
        self.edit_key_name.insert(0, data.get("key", ""))

        duration_type, duration_value = "يوم", ""
        for unit, fk in [
            ("ثانية","durationSeconds"), ("دقيقة","durationMinutes"),
            ("ساعة","durationHours"),   ("أسبوع","durationWeeks"),
            ("شهر","durationMonths"),
            ("سنة","durationYears"),
        ]:
            if fk in data:
                duration_type, duration_value = unit, data[fk]
                break
        else:
            if data.get("durationDays") == -1:
                duration_type = "مدى الحياة"
            elif "durationDays" in data:
                duration_type, duration_value = "يوم", data["durationDays"]

        self.edit_duration_sc.set(duration_type)
        self.edit_amount_entry.delete(0, "end")
        if duration_value != "":
            self.edit_amount_entry.insert(0, str(duration_value))

        for widget, key in [
            (self.edit_comment_entry,    "comment"),
            (self.edit_activation_entry, "activationDate"),
            (self.edit_expiry_entry,     "expiryDate"),
            (self.edit_hwid_entry,       "hwid"),
            (self.edit_mac_entry,        "macAddress"),
        ]:
            widget.delete(0, "end")
            if key in data:
                widget.insert(0, str(data[key]))

        if data.get("enabled") == "yes":
            self.edit_enabled.select()
        else:
            self.edit_enabled.deselect()

    def save_edited_key(self):
        if not self.selected_key_data:
            messagebox.showwarning("تنبيه", "حمّل كوداً أولاً")
            return
        try:
            item = self.selected_key_data
            item["key"]     = self.edit_key_name.get().strip()
            item["comment"] = self.edit_comment_entry.get().strip()
            item["enabled"] = "yes" if self.edit_enabled.get() else "no"

            for k in ["durationSeconds","durationMinutes","durationHours",
                      "durationDays","durationWeeks","durationMonths","durationYears"]:
                item.pop(k, None)

            duration_type = self.edit_duration_sc.get()
            if duration_type == "مدى الحياة":
                item["durationDays"] = -1
            else:
                item[self.duration_map[duration_type]] = int(
                    self.edit_amount_entry.get().strip()
                )

            for val, key in [
                (self.edit_activation_entry.get().strip(), "activationDate"),
                (self.edit_expiry_entry.get().strip(),     "expiryDate"),
                (self.edit_hwid_entry.get().strip(),       "hwid"),
                (self.edit_mac_entry.get().strip(),        "macAddress"),
            ]:
                if val: item[key] = val
                else:   item.pop(key, None)

            self.gm.save_json(SECRET_CONFIG["GITHUB_FILE_PATH"],
                              self.keys_data, self.current_sha, "Edited Key")
            self.refresh()
            messagebox.showinfo("نجاح ✅", "تم حفظ التعديلات")
        except Exception as e:
            messagebox.showerror("خطأ", str(e))

    def reset_activation_data(self):
        if not self.selected_key_data:
            messagebox.showwarning("تنبيه", "حمّل كوداً أولاً")
            return
        if not messagebox.askyesno("تأكيد", "هتتمسح بيانات التفعيل. متأكد؟"):
            return
        for k in ["activationDate", "expiryDate", "hwid", "macAddress"]:
            self.selected_key_data.pop(k, None)
        self.gm.save_json(SECRET_CONFIG["GITHUB_FILE_PATH"],
                          self.keys_data, self.current_sha, "Reset Activation")
        self.refresh()
        self.load_selected_key()
        messagebox.showinfo("نجاح ✅", "تم تصفير بيانات التفعيل")

    # ═════════════════════════════════════════════════════════════════════════
    #  Delete key
    # ═════════════════════════════════════════════════════════════════════════
    def delete_selected_key(self):
        selected = self.delete_key_sc.get()
        if not selected:
            messagebox.showwarning("تنبيه", "اختر كوداً أولاً")
            return
        if not messagebox.askyesno("تأكيد الحذف ⚠️", f'هتحذف الكود "{selected}". متأكد؟'):
            return
        self.keys_data = [i for i in self.keys_data if i.get("key") != selected]
        self.gm.save_json(SECRET_CONFIG["GITHUB_FILE_PATH"],
                          self.keys_data, self.current_sha, "Deleted Key")
        self.refresh()
        messagebox.showinfo("نجاح ✅", f'تم حذف الكود "{selected}"')

    def delete_multiple_keys(self):
        found = self.delete_multi_combo.get_selected()
        if not found:
            messagebox.showwarning("تنبيه", "اختر أكواداً للحذف أولاً")
            return

        msg = f"سيتم حذف {len(found)} كود:\n" + "\n".join(f"- {k}" for k in found)
        if not messagebox.askyesno("تأكيد الحذف ⚠️", msg):
            return

        found_set = set(found)
        self.keys_data = [i for i in self.keys_data if i.get("key") not in found_set]
        self.gm.save_json(SECRET_CONFIG["GITHUB_FILE_PATH"],
                          self.keys_data, self.current_sha, "Deleted multiple keys")
        self.delete_multi_combo.clear_selection()
        self.refresh()
        messagebox.showinfo("نجاح ✅", f"تم حذف {len(found)} كود")

    def delete_expired_keys(self):
        today = date.today()
        expired = []
        for item in self.keys_data:
            exp = item.get("expiryDate")
            if not exp:
                continue
            try:
                exp_date = date.fromisoformat(str(exp)[:10])
            except Exception:
                continue
            if exp_date < today:
                expired.append(item)

        if not expired:
            messagebox.showinfo("معلومة", "لا يوجد أكواد منتهية الصلاحية حاليًا")
            return

        names = "\n".join(f"- {i.get('key', '')}" for i in expired)
        if not messagebox.askyesno(
            "تأكيد الحذف ⚠️",
            f"سيتم حذف {len(expired)} كود منتهي الصلاحية:\n{names}\nمتأكد؟",
        ):
            return

        expired_ids = {id(i) for i in expired}
        self.keys_data = [i for i in self.keys_data if id(i) not in expired_ids]
        self.gm.save_json(SECRET_CONFIG["GITHUB_FILE_PATH"],
                          self.keys_data, self.current_sha, "Deleted expired keys")
        self.refresh()
        messagebox.showinfo("نجاح ✅", f"تم حذف {len(expired)} كود منتهي الصلاحية")


if __name__ == "__main__":
    _root = tk.Tk()
    _root.withdraw()

    # ─────────────────────────────────────────────────────────────

    if not check_hwid_authorization():
        _root.destroy()
        sys.exit(0)
    _root.destroy()

    app = App()
    if app.winfo_exists():
        app.mainloop()

        #pyinstaller --onefile --noconsole --icon=panda_icon.ico --name="Panda-Toolbox-keys" main.py