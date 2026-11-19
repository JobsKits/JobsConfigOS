"""Jobs desktop panel. Opening and previewing never execute a Git mutation."""
from __future__ import annotations

import argparse
from datetime import datetime
import json
from pathlib import Path
import sys
import threading
import traceback

from PySide6.QtCore import QEvent, QSettings, QStandardPaths, Qt, QThread, QTimer, Signal
from PySide6.QtGui import QColor, QDesktopServices, QFont, QPalette, QIcon
from PySide6.QtCore import QUrl
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QComboBox, QDialog, QDialogButtonBox, QFileDialog,
    QFrame, QHBoxLayout, QHeaderView, QLabel, QLineEdit, QMainWindow, QMessageBox,
    QPlainTextEdit, QProgressBar, QPushButton, QSizePolicy, QSplitter,
    QTabWidget, QTableWidget, QTableWidgetItem, QVBoxLayout, QWidget,
)

from . import __version__
from .git_service import build_plan, execute_plan, inspect_repo
from .i18n import LANGUAGES, translate, render_plan


class WrappedOption(QWidget):
    """Wrap long translations while retaining the native checkbox interaction."""
    toggled = Signal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(7)
        self.checkbox = QCheckBox()
        self.caption = QLabel()
        self.caption.setWordWrap(True)
        self.caption.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        self.caption.installEventFilter(self)
        self.checkbox.toggled.connect(self.toggled.emit)
        layout.addWidget(self.checkbox, 0, Qt.AlignmentFlag.AlignTop)
        layout.addWidget(self.caption, 1)

    def setText(self, text):
        """Translate the visible label and the keyboard-accessible control together."""
        self.caption.setText(text)
        self.checkbox.setAccessibleName(text)
        self._fit_caption()

    def _fit_caption(self):
        """Reserve every translated line even when the splitter is compressed."""
        width = max(40, self.width() - self.checkbox.sizeHint().width() - 7)
        required = max(self.checkbox.sizeHint().height(), self.caption.fontMetrics().boundingRect(0, 0, width, 10000, Qt.TextFlag.TextWordWrap, self.caption.text()).height() + 4)
        if self.caption.minimumHeight() != required:
            self.caption.setMinimumHeight(required)
        if self.minimumHeight() != required + 2:
            self.setMinimumHeight(required + 2)

    def resizeEvent(self, event):
        """Recalculate wrapped height after horizontal layout or window changes."""
        super().resizeEvent(event)
        QTimer.singleShot(0, self._fit_caption)

    def setChecked(self, checked):
        """Delegate state changes to the native checkbox and its standard signal."""
        self.checkbox.setChecked(checked)

    def isChecked(self):
        """Expose the native checked state to operation planning."""
        return self.checkbox.isChecked()

    def eventFilter(self, watched, event):
        """Make the complete wrapped caption a single, nonduplicated toggle target."""
        if watched is self.caption and event.type() == QEvent.Type.MouseButtonRelease:
            if event.button() == Qt.MouseButton.LeftButton and self.isEnabled():
                self.checkbox.click()
                return True
        return super().eventFilter(watched, event)


class Task(QThread):
    """Run bounded Git work away from the UI and forward logs as queued signals."""
    succeeded = Signal(object)
    failed = Signal(str)
    line = Signal(str)

    def __init__(self, callback, parent=None):
        super().__init__(parent)
        self.callback = callback
        self.cancel = threading.Event()

    def run(self):
        try:
            self.succeeded.emit(self.callback(self.line.emit, self.cancel))
        except Exception as error:
            self.failed.emit(str(error))


class Window(QMainWindow):
    """Keep repository selection, reviewed plans, and active work in one window."""
    def __init__(self, root: Path | None = None):
        super().__init__()
        self.settings = QSettings("Jobs", "JobsGitManager")
        self.locale = str(self.settings.value("language", "zh_CN"))
        if self.locale not in LANGUAGES:
            self.locale = "zh_CN"
        self.theme = str(self.settings.value("theme", "system"))
        if self.theme not in ("light", "dark", "system"):
            self.theme = "system"
        self.repo = root
        self.rows = []
        self.plan = None
        self.task = None
        self.log_file = None
        self.state = "ready"
        self.refresh_after_task = False
        self.labels = []
        self.resize(1200, 850)
        self.setMinimumSize(960, 700)
        self._build_ui()
        self._translate_ui()
        self._theme_ui()
        QApplication.styleHints().colorSchemeChanged.connect(self._system_theme_changed)
        if root:
            self.path_edit.setText(str(root))
            QTimer.singleShot(0, self.refresh)

    def t(self, key, **values):
        """Resolve a complete catalog entry for the current interface language."""
        return translate(self.locale, key, **values)

    def label(self, key, object_name=""):
        """Track static labels so language changes also update existing widgets."""
        widget = QLabel()
        widget.setObjectName(object_name)
        widget.setWordWrap(True)
        self.labels.append((widget, key))
        return widget

    def button(self, key, callback, object_name=""):
        """Create a keyboard-accessible button and retain its translation key."""
        button = QPushButton()
        button.setObjectName(object_name)
        button.clicked.connect(callback)
        self.labels.append((button, key))
        return button

    def _build_ui(self):
        """Arrange a repository table, an operation rail, and review/log panels."""
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setContentsMargins(26, 22, 26, 18)
        layout.setSpacing(15)
        heading = QHBoxLayout()
        titles = QVBoxLayout()
        title_row = QHBoxLayout()
        title_row.setSpacing(10)
        self.title_icon = QLabel()
        self.title_icon.setObjectName("titleIcon")
        self.title_icon.setFixedSize(34, 34)
        self.title_icon.setAccessibleName("Git")
        git_icon = QIcon(str(Path(__file__).resolve().parent / "assets/git.svg"))
        self.setWindowIcon(git_icon)
        self.title_icon.setPixmap(git_icon.pixmap(34, 34))
        title_row.addWidget(self.title_icon)
        title_row.addWidget(self.label("title", "title"), 1)
        titles.addLayout(title_row)
        titles.addWidget(self.label("subtitle", "muted"))
        heading.addLayout(titles, 1)
        settings = QHBoxLayout()
        settings.setSpacing(16)
        for key in ("language", "theme"):
            line = QHBoxLayout()
            setting_label = self.label(key)
            setting_label.setProperty("labelPrefix", "🌐 " if key == "language" else "🌓 ")
            setting_label.setWordWrap(False)
            line.addWidget(setting_label)
            combo = QComboBox()
            combo.setMinimumWidth(150)
            setattr(self, key + "_combo", combo)
            line.addWidget(combo)
            settings.addLayout(line)
        for code, name in LANGUAGES.items():
            self.language_combo.addItem(name, code)
        self.language_combo.setCurrentIndex(list(LANGUAGES).index(self.locale))
        self.language_combo.currentIndexChanged.connect(self._language_changed)
        for key in ("light", "dark", "system"):
            self.theme_combo.addItem("", key)
        self.theme_combo.setCurrentIndex(("light", "dark", "system").index(self.theme))
        self.theme_combo.currentIndexChanged.connect(self._theme_changed)
        heading.addLayout(settings)
        layout.addLayout(heading)
        path_row = QHBoxLayout()
        self.path_edit = QLineEdit()
        self.path_edit.setReadOnly(True)
        self.choose_button = self.button("choose", self.choose)
        self.refresh_button = self.button("refresh", self.refresh)
        path_row.addWidget(self.path_edit, 1)
        path_row.addWidget(self.choose_button)
        path_row.addWidget(self.refresh_button)
        layout.addLayout(path_row)
        upper = QSplitter(Qt.Orientation.Horizontal)
        left = QWidget()
        left_layout = QVBoxLayout(left)
        left_layout.setContentsMargins(0, 0, 10, 0)
        selection = QHBoxLayout()
        self.count = QLabel()
        selection.addWidget(self.count, 1)
        self.all_button = self.button("select_all", lambda: self._select_all(True))
        self.clear_button = self.button("clear", lambda: self._select_all(False))
        selection.addWidget(self.all_button)
        selection.addWidget(self.clear_button)
        left_layout.addLayout(selection)
        self.table = QTableWidget(0, 6)
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.table.verticalHeader().hide()
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        self.table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        for column in range(2, 6):
            self.table.horizontalHeader().setSectionResizeMode(column, QHeaderView.ResizeMode.ResizeToContents)
        self.table.itemChanged.connect(self._invalidate_plan)
        left_layout.addWidget(self.table, 1)
        self.empty = self.label("empty", "muted")
        self.empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.reload_button = self.button("reload", self.refresh)
        left_layout.addWidget(self.empty)
        left_layout.addWidget(self.reload_button)
        upper.addWidget(left)
        rail = QFrame()
        rail.setObjectName("rail")
        rail.setMaximumWidth(330)
        rail.setMinimumWidth(250)
        rail_layout = QVBoxLayout(rail)
        rail_layout.setContentsMargins(16, 16, 16, 16)
        rail_layout.setSpacing(10)
        rail_layout.addWidget(self.label("action", "section"))
        self.action_combo = QComboBox()
        for action in ("download", "align", "register"):
            self.action_combo.addItem("", action)
        self.action_combo.currentIndexChanged.connect(self._operation_changed)
        rail_layout.addWidget(self.action_combo)
        self.description = QLabel()
        self.description.setWordWrap(True)
        self.description.setObjectName("muted")
        rail_layout.addWidget(self.description)
        self.recursive = WrappedOption()
        self.recursive.setChecked(True)
        self.recursive.toggled.connect(self._invalidate_plan)
        rail_layout.addWidget(self.recursive)
        self.remote = WrappedOption()
        self.remote.setChecked(True)
        self.remote.toggled.connect(self._invalidate_plan)
        rail_layout.addWidget(self.remote)
        rail_layout.addStretch()
        self.preview_button = self.button("preview", self.preview, "primary")
        self.run_button = self.button("execute", self.execute, "execute")
        self.run_button.setEnabled(False)
        rail_layout.addWidget(self.preview_button)
        rail_layout.addWidget(self.run_button)
        upper.addWidget(rail)
        upper.setStretchFactor(0, 1)
        self.operation_rail = rail
        self.upper_panel = upper
        vertical = QSplitter(Qt.Orientation.Vertical)
        vertical.addWidget(upper)
        self.tabs = QTabWidget()
        self.preview_text = QPlainTextEdit()
        self.preview_text.setReadOnly(True)
        self.log_text = QPlainTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setMaximumBlockCount(15000)
        for widget in (self.preview_text, self.log_text):
            widget.setFont(QFont("Menlo" if sys.platform == "darwin" else "Consolas", 11))
            widget.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)
        self.tabs.addTab(self.preview_text, "")
        self.tabs.addTab(self.log_text, "")
        vertical.addWidget(self.tabs)
        vertical.setSizes([380, 230])
        layout.addWidget(vertical, 1)
        footer = QHBoxLayout()
        self.status = QLabel()
        footer.addWidget(self.status, 1)
        self.progress = QProgressBar()
        self.progress.setRange(0, 0)
        self.progress.setFixedWidth(140)
        self.progress.hide()
        footer.addWidget(self.progress)
        self.log_button = self.button("log_location", self.open_logs)
        footer.addWidget(self.log_button)
        self.cancel_button = self.button("cancel", self.cancel_task)
        self.cancel_button.setEnabled(False)
        footer.addWidget(self.cancel_button)
        layout.addLayout(footer)
        layout.addWidget(self.label("intro", "muted"))

    def _translate_ui(self):
        """Refresh all visible labels while preserving data and selections."""
        self.setWindowTitle(self.t("title"))
        for widget, key in self.labels:
            widget.setText((widget.property("labelPrefix") or "") + self.t(key))
        self.path_edit.setPlaceholderText(self.t("repository"))
        self.path_edit.setAccessibleName(self.t("repository"))
        self.language_combo.setAccessibleName(self.t("language"))
        self.theme_combo.setAccessibleName(self.t("theme"))
        for index, key in enumerate(("light", "dark", "system")):
            self.theme_combo.setItemText(index, self.t(key))
        for index, key in enumerate(("download", "align", "register")):
            self.action_combo.setItemText(index, self.t(key))
        self.recursive.setText(self.t("recursive"))
        self.remote.setText(self.t("remote"))
        self.table.setHorizontalHeaderLabels(["", self.t("path"), self.t("registered"), self.t("branch"), self.t("head"), self.t("dirty")])
        self.tabs.setTabText(0, self.t("plan"))
        self.tabs.setTabText(1, self.t("log"))
        self.status.setText(self.t(self.state))
        self._operation_changed(invalidate=False)
        self._populate_table(preserve=True)
        if self.plan is not None:
            self.preview_text.setPlainText(render_plan(self.plan, self.locale))

    def _language_changed(self):
        """Persist the selected language without recreating an in-flight task."""
        self.locale = self.language_combo.currentData()
        self.settings.setValue("language", self.locale)
        self._translate_ui()

    def _theme_changed(self):
        """Save the explicit appearance policy and update the entire palette."""
        self.theme = self.theme_combo.currentData()
        self.settings.setValue("theme", self.theme)
        self._theme_ui()

    def _system_theme_changed(self, *_):
        """Follow live system appearance changes only in system mode."""
        if self.theme == "system":
            self._theme_ui()

    def _theme_ui(self):
        """Apply matching palettes to tables, menus, dialogs, and log content."""
        dark = self.theme == "dark" or (
            self.theme == "system" and QApplication.styleHints().colorScheme() == Qt.ColorScheme.Dark
        )
        bg, surface, text, muted, border, alternate = (
            ("#20242b", "#282e37", "#eef1f6", "#aeb8c8", "#47515f", "#2e3540") if dark else
            ("#f4f6fa", "#ffffff", "#253047", "#63718a", "#d8dfeb", "#f0f4fa")
        )
        palette = QPalette()
        for role, color in (
            (QPalette.ColorRole.Window, bg), (QPalette.ColorRole.WindowText, text),
            (QPalette.ColorRole.Base, surface), (QPalette.ColorRole.AlternateBase, alternate),
            (QPalette.ColorRole.Text, text), (QPalette.ColorRole.Button, surface),
            (QPalette.ColorRole.ButtonText, text), (QPalette.ColorRole.ToolTipBase, surface),
            (QPalette.ColorRole.ToolTipText, text), (QPalette.ColorRole.Highlight, "#315fc4"),
            (QPalette.ColorRole.HighlightedText, "#ffffff"), (QPalette.ColorRole.PlaceholderText, muted),
        ):
            palette.setColor(role, QColor(color))
        for role in (QPalette.ColorRole.Text, QPalette.ColorRole.ButtonText, QPalette.ColorRole.WindowText):
            palette.setColor(QPalette.ColorGroup.Disabled, role, QColor(muted))
        QApplication.instance().setPalette(palette)
        QApplication.instance().setStyleSheet(f"""
            QWidget {{ font-size: 13px; }}
            QMainWindow, QDialog {{ background: {bg}; }}
            QLabel#title {{ font-size: 26px; font-weight: 650; }}
            QLabel#section {{ font-size: 16px; font-weight: 600; }}
            QLabel#muted {{ color: {muted}; font-size: 12px; }}
            QFrame#rail {{ background: {surface}; border: 1px solid {border}; border-radius: 8px; }}
            QPushButton, QComboBox {{ min-height: 28px; padding: 3px 10px; border: 1px solid {border}; border-radius: 5px; background: {surface}; color: {text}; }}
            QPushButton:hover {{ border-color: #537ed4; }}
            QPushButton:focus, QComboBox:focus, QLineEdit:focus {{ border: 2px solid #537ed4; }}
            QPushButton#primary {{ background: #315fc4; color: white; border: 1px solid #315fc4; }}
            QPushButton#execute:enabled {{ background: #26714c; color: white; border-color: #26714c; }}
            QPushButton:disabled {{ color: {muted}; background: {bg}; }}
            QLineEdit, QPlainTextEdit, QTableWidget {{ border: 1px solid {border}; border-radius: 5px; background: {surface}; color: {text}; selection-background-color: #315fc4; selection-color: white; }}
            QLineEdit {{ padding: 7px; }}
            QHeaderView::section {{ background: {alternate}; color: {text}; padding: 8px; border: none; border-bottom: 1px solid {border}; }}
            QTableCornerButton::section {{ background: {alternate}; border: none; }}
            QTableWidget::item {{ padding: 5px; }}
            QComboBox QAbstractItemView {{ background: {surface}; color: {text}; selection-background-color: #315fc4; selection-color: white; }}
            QTabWidget::pane {{ border: 1px solid {border}; }}
            QTabBar::tab {{ padding: 8px 18px; background: {alternate}; color: {text}; }}
            QTabBar::tab:selected {{ background: {surface}; border-top: 2px solid #537ed4; }}
            QScrollBar {{ background: {bg}; }}
            QScrollBar::handle {{ background: {border}; border-radius: 4px; min-width: 20px; min-height: 20px; }}
            QCheckBox {{ spacing: 7px; }}
        """)

    def _operation_changed(self, *_, invalidate=True):
        """Expose only the options meaningful for the selected operation."""
        action = self.action_combo.currentData()
        self.description.setText(self.t(action + "_desc"))
        self.recursive.setVisible(action == "download")
        self.remote.setVisible(action == "download")
        if invalidate:
            self._invalidate_plan()
        QTimer.singleShot(0, self._fit_operation_rail)

    def _fit_operation_rail(self):
        """Reserve the operation controls' full height before the log splitter shrinks."""
        width = max(100, self.operation_rail.width() - 34)
        description_height = self.description.fontMetrics().boundingRect(0, 0, width, 10000, Qt.TextFlag.TextWordWrap, self.description.text()).height() + 4
        if self.description.minimumHeight() != description_height:
            self.description.setMinimumHeight(description_height)
        self.recursive._fit_caption()
        self.remote._fit_caption()
        self.upper_panel.setMinimumHeight(max(330, self.operation_rail.layout().minimumSize().height() + 8))

    def resizeEvent(self, event):
        """Reflow long option text without allowing the vertical splitter to crop it."""
        super().resizeEvent(event)
        if hasattr(self, "operation_rail"):
            QTimer.singleShot(0, self._fit_operation_rail)

    def _invalidate_plan(self, *_):
        """Changing a target or option requires a fresh reviewed operation plan."""
        self.plan = None
        self.run_button.setEnabled(False)
        self.preview_text.clear()

    def _selected_paths(self):
        """Read checkbox state independently of the table's visual row selection."""
        return [row["path"] for i, row in enumerate(self.rows)
                if self.table.item(i, 0).checkState() == Qt.CheckState.Checked]

    def _select_all(self, checked):
        """Select or clear all currently discovered child repositories."""
        for row in range(self.table.rowCount()):
            self.table.item(row, 0).setCheckState(Qt.CheckState.Checked if checked else Qt.CheckState.Unchecked)

    def _populate_table(self, preserve=False):
        """Display actual local repository facts with explicit empty-state controls."""
        selected = set(self._selected_paths()) if preserve and self.table.rowCount() == len(self.rows) else set()
        self.table.blockSignals(True)
        self.table.setRowCount(len(self.rows))
        for index, row in enumerate(self.rows):
            checkbox = QTableWidgetItem()
            checkbox.setFlags(Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsUserCheckable)
            checkbox.setCheckState(Qt.CheckState.Checked if row["path"] in selected else Qt.CheckState.Unchecked)
            checkbox.setToolTip(row["path"])
            self.table.setItem(index, 0, checkbox)
            status = row.get("status", "clean")
            state_key = status if status in ("dirty", "missing", "clean", "unregistered") else "missing"
            values = [row["path"], self.t("registered" if row.get("registered") else "unregistered"),
                      row.get("branch") or "—", (row.get("head") or "—")[:10], self.t(state_key)]
            for column, value in enumerate(values, 1):
                item = QTableWidgetItem(str(value))
                item.setToolTip(str(row.get("url") or "—") if column == 1 else str(value))
                self.table.setItem(index, column, item)
            self.table.setRowHeight(index, 38)
        self.table.blockSignals(False)
        self.count.setText(self.t("count", n=len(self.rows)))
        self.empty.setVisible(not self.rows)
        self.reload_button.setVisible(not self.rows)
        self.table.setVisible(bool(self.rows))

    def choose(self):
        """Use the platform directory chooser rather than assuming a working directory."""
        folder = QFileDialog.getExistingDirectory(self, self.t("choose"), str(self.repo or Path.home()))
        if folder:
            self.repo = Path(folder).resolve()
            self.path_edit.setText(str(self.repo))
            self.refresh()

    def refresh(self):
        """Inspect the selected parent without mutating its working tree or index."""
        if self.task:
            return
        if not self.repo:
            self.choose()
            return
        self._invalidate_plan()
        self.rows = []
        self._populate_table()
        self._start(lambda _log, cancel: inspect_repo(self.repo, cancel=cancel), self._scanned)

    def _scanned(self, rows):
        """Replace stale table data only after a complete scan succeeds."""
        self.rows = rows
        self._populate_table()

    def preview(self):
        """Build a snapshot-bound plan without running any of its commands."""
        paths = self._selected_paths()
        if not paths:
            QMessageBox.information(self, self.t("title"), self.t("no_selection"))
            return
        action = self.action_combo.currentData()
        root = self.repo
        recursive, remote = self.recursive.isChecked(), self.remote.isChecked()
        self._invalidate_plan()
        self._start(lambda _log, cancel: build_plan(root, action, paths, recursive=recursive, remote=remote, cancel=cancel), self._planned)

    def _planned(self, plan):
        """Keep the exact plan displayed for the user's later confirmation."""
        self.plan = plan
        self.preview_text.setPlainText(render_plan(plan, self.locale))
        self.tabs.setCurrentIndex(0)

    def execute(self):
        """Ask for explicit confirmation, defaulting to cancel, then run that plan."""
        if not self.plan or self.task:
            return
        dialog = QDialog(self)
        dialog.setWindowTitle(self.t("confirm"))
        dialog.resize(830, 540)
        box = QVBoxLayout(dialog)
        explanation = QLabel(self.t("confirm_body"))
        explanation.setWordWrap(True)
        box.addWidget(explanation)
        details = QPlainTextEdit(render_plan(self.plan, self.locale))
        details.setReadOnly(True)
        box.addWidget(details)
        buttons = QDialogButtonBox()
        yes = buttons.addButton(self.t("execute"), QDialogButtonBox.ButtonRole.AcceptRole)
        no = buttons.addButton(self.t("cancel"), QDialogButtonBox.ButtonRole.RejectRole)
        no.setDefault(True)
        yes.setAutoDefault(False)
        buttons.accepted.connect(dialog.accept)
        buttons.rejected.connect(dialog.reject)
        box.addWidget(buttons)
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return
        plan = self.plan
        self._invalidate_plan()
        self.tabs.setCurrentIndex(1)
        self._begin_log()
        self._start(lambda log, cancel: execute_plan(plan, log=log, cancel=cancel), self._executed)

    def _executed(self, result):
        """Show the backend's result without claiming that changes were committed."""
        self._append_log(json.dumps(result, ensure_ascii=False, default=str))
        self.refresh_after_task = True

    def _start(self, callback, on_success):
        """Own one task at a time and make busy state visible until the thread ends."""
        if self.task:
            return
        task = Task(callback, self)
        self.task = task
        self.state = "busy"
        self._busy_ui(True)
        task.line.connect(self._append_log)
        task.succeeded.connect(on_success)
        task.succeeded.connect(lambda _result: self._set_state("done"))
        task.failed.connect(self._task_failed)
        task.finished.connect(self._task_finished)
        task.start()

    def _set_state(self, state):
        """Keep the footer status translatable after task completion."""
        self.state = state
        self.status.setText(self.t(state))

    def _task_failed(self, message):
        """Expose the actual Git failure and invalidate all previously reviewed plans."""
        self._invalidate_plan()
        self._set_state("failed")
        self._append_log(message)
        self.tabs.setCurrentIndex(1)
        QMessageBox.warning(self, self.t("failed"), message)

    def _task_finished(self):
        """Release a finished worker only after all queued result signals arrive."""
        worker = self.task
        self.task = None
        self._busy_ui(False)
        if worker:
            worker.deleteLater()
        if self.refresh_after_task:
            self.refresh_after_task = False
            QTimer.singleShot(0, self.refresh)

    def _busy_ui(self, busy):
        """Prevent targets and options from changing beneath an active task."""
        for widget in (self.choose_button, self.refresh_button, self.table, self.action_combo,
                       self.recursive, self.remote, self.preview_button, self.all_button,
                       self.clear_button, self.reload_button):
            widget.setEnabled(not busy)
        self.run_button.setEnabled(not busy and self.plan is not None)
        self.cancel_button.setEnabled(busy)
        self.progress.setVisible(busy)
        self.status.setText(self.t(self.state))

    def cancel_task(self):
        """Request cooperative cancellation without terminating a thread mid-write."""
        if self.task:
            self.task.cancel.set()
            self.cancel_button.setEnabled(False)

    def _log_directory(self):
        """Resolve a writable per-user log directory independent of the bundle."""
        return Path(QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppLocalDataLocation)) / "logs"

    def _begin_log(self):
        """Create a private, unique execution log only after execution is confirmed."""
        directory = self._log_directory()
        directory.mkdir(parents=True, exist_ok=True)
        self.log_file = directory / (datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".log")
        self.log_file.touch(mode=0o600)
        self._append_log(f"JobsGitManager {__version__}")

    def _append_log(self, text):
        """Append text while preserving the user's manual log browsing position."""
        scrollbar = self.log_text.verticalScrollBar()
        following = scrollbar.value() >= scrollbar.maximum() - 3
        position = scrollbar.value()
        self.log_text.appendPlainText(str(text))
        if not following:
            scrollbar.setValue(position)
        if self.log_file:
            with self.log_file.open("a", encoding="utf-8") as stream:
                stream.write(str(text) + "\n")

    def open_logs(self):
        """Open existing logs with the platform's file manager."""
        directory = self._log_directory()
        if not directory.exists():
            directory = directory.parent
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(directory)))

    def closeEvent(self, event):
        """Keep an active Git operation alive until cancellation has completed."""
        if self.task:
            QMessageBox.information(self, self.t("title"), self.t("close_busy"))
            event.ignore()
        else:
            event.accept()


def default_repository() -> Path | None:
    """Find an enclosing checkout from the executable or source, never from cwd."""
    location = Path(sys.executable).resolve() if getattr(sys, "frozen", False) else Path(__file__).resolve()
    for parent in location.parents:
        if (parent / ".git").exists():
            return parent
    return None


def main(argv=None):
    """Launch a selected checkout; a copied standalone app asks for its repository."""
    parser = argparse.ArgumentParser(description="Jobs Git repository manager")
    parser.add_argument("--repo", type=Path)
    parser.add_argument("--smoke-test", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    application = QApplication.instance() or QApplication(sys.argv[:1])
    application.setApplicationName("JobsGitManager")
    application.setApplicationVersion(__version__)
    application.setStyle("Fusion")
    window = Window(args.repo.resolve() if args.repo else default_repository())
    window.show()
    if args.smoke_test:
        def finish_smoke():
            """Save a screenshot and machine-readable evidence of packaged startup."""
            if window.task:
                QTimer.singleShot(200, finish_smoke)
                return
            output = args.smoke_test
            output.mkdir(parents=True, exist_ok=True)
            window.grab().save(str(output / "window.png"))
            (output / "startup.json").write_text(json.dumps({
                "frozen": bool(getattr(sys, "frozen", False)), "version": __version__,
                "rows": len(window.rows), "state": window.state, "repo": str(window.repo),
            }, ensure_ascii=False, indent=2), encoding="utf-8")
            application.quit()
        QTimer.singleShot(1200, finish_smoke)
    return application.exec()


if __name__ == "__main__":
    raise SystemExit(main())
