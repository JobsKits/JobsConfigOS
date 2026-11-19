"""Complete interface catalog; command output remains Git's original diagnostics."""
LANGUAGES = {
    "zh_CN": "简体中文", "zh_TW": "繁體中文", "bo": "བོད་ཡིག",
    "en": "English", "ja": "日本語", "fr": "Français", "es": "Español",
    "de": "Deutsch", "ru": "Русский", "ko": "한국어",
}
KEYS = (
    "title subtitle choose refresh repository path branch head url registered unregistered dirty missing clean "
    "empty reload action download align register download_desc align_desc register_desc recursive remote "
    "preview execute cancel select_all clear plan log ready busy done failed confirm confirm_body close_busy "
    "no_selection read_only language theme light dark system count log_location intro"
).split()
# Keep positional catalogs exhaustive: an incomplete translation fails at import time.
CATALOGS = {
"zh_CN": [
"Git 父／子仓管理", "父子仓配置，集中在这里。", "选择仓库", "刷新", "当前仓库", "子仓路径", "分支", "当前提交", "远端地址", "已登记", "未登记", "有改动", "未下载", "干净",
"没有发现子仓。选择其他仓库，或重新扫描。", "重新扫描", "操作", "下载子模块", "对齐父子仓引用", "补齐 .gitmodules", "同步已登记的子模块；保留本地改动，遇冲突停止。", "将所选子仓当前提交登记到父仓索引。", "发现独立子仓并补齐登记；保留已有远端与分支。", "递归处理后代子模块", "跟随远端分支最新提交", "预览操作计划", "确认并执行", "取消任务", "全选", "取消选择", "操作计划", "执行日志", "就绪", "处理中…", "操作完成", "操作未完成", "确认执行此计划？", "请核对下方计划。将修改所选仓库；已完成的步骤不会因取消自动撤回。", "任务仍在执行，请先取消并等待结束。", "请先勾选至少一个子仓。", "进入面板只扫描；写操作须预览并确认。", "语言", "主题", "白天", "黑夜", "跟随系统", "{n} 个子仓", "日志目录", "不包含缓存清理。Git 原始诊断与命令保留原文。"
],
"zh_TW": [
"Git 父／子倉管理", "父子倉設定，集中在這裡。", "選擇倉庫", "重新整理", "目前倉庫", "子倉路徑", "分支", "目前提交", "遠端位址", "已登記", "未登記", "有變更", "未下載", "乾淨",
"找不到子倉。請選擇其他倉庫，或重新掃描。", "重新掃描", "操作", "下載子模組", "對齊父子倉引用", "補齊 .gitmodules", "同步已登記子模組；保留本機變更，遇衝突停止。", "將所選子倉目前提交登記到父倉索引。", "探索獨立子倉並補齊登記；保留既有遠端與分支。", "遞迴處理後代子模組", "跟隨遠端分支最新提交", "預覽操作計畫", "確認並執行", "取消工作", "全選", "取消選取", "操作計畫", "執行記錄", "就緒", "處理中…", "操作完成", "操作未完成", "確認執行此計畫？", "請核對下方計畫。將修改所選倉庫；已完成步驟不會因取消自動還原。", "工作仍在執行，請先取消並等待結束。", "請先勾選至少一個子倉。", "進入面板僅掃描；寫入須預覽並確認。", "語言", "主題", "白天", "黑夜", "跟隨系統", "{n} 個子倉", "記錄目錄", "不包含快取清理。Git 原始診斷與命令保留原文。"
],
"en": [
"Git parent/child manager", "One place for parent and child repositories.", "Choose repository", "Refresh", "Repository", "Child repository", "Branch", "Current commit", "Remote URL", "Registered", "Unregistered", "Modified", "Not downloaded", "Clean",
"No child repositories found. Choose another repository or scan again.", "Scan again", "Operation", "Download submodules", "Align parent references", "Complete .gitmodules", "Sync registered submodules; preserve local changes and stop on conflicts.", "Record each selected child's current commit in the parent index.", "Discover independent children and register them; preserve remotes and branches.", "Include descendant submodules", "Follow the latest remote branch commit", "Preview operation", "Confirm and run", "Cancel task", "Select all", "Clear selection", "Operation plan", "Execution log", "Ready", "Working…", "Operation completed", "Operation incomplete", "Run this plan?", "Review the plan below. Selected repositories will change; cancellation does not undo completed steps.", "A task is running. Cancel it and wait for it to finish first.", "Select at least one child repository.", "Opening this panel only scans. Preview and confirm before writing.", "Language", "Theme", "Light", "Dark", "System", "{n} child repositories", "Log directory", "Cache cleanup is separate. Git diagnostics and commands retain their original text."
],
"ja": [
"Git 親／子リポジトリ管理", "親子リポジトリの設定を一か所に。", "リポジトリを選択", "更新", "現在のリポジトリ", "子リポジトリ", "ブランチ", "現在のコミット", "リモート URL", "登録済み", "未登録", "変更あり", "未取得", "変更なし",
"子リポジトリがありません。別の場所を選ぶか再スキャンしてください。", "再スキャン", "操作", "サブモジュールを取得", "親の参照を更新", ".gitmodules を補完", "登録済みモジュールを同期。ローカル変更を保護し、競合時は停止します。", "選択した子の現在のコミットを親のインデックスに記録します。", "独立した子を検出して登録。既存のリモートとブランチを保持します。", "下位サブモジュールも処理", "リモートブランチの最新に追従", "操作をプレビュー", "確認して実行", "処理を中止", "すべて選択", "選択解除", "操作計画", "実行ログ", "準備完了", "処理中…", "操作完了", "操作未完了", "この計画を実行しますか？", "以下の計画を確認してください。選択したリポジトリを変更します。中止しても完了した手順は元に戻りません。", "処理中です。中止して終了を待ってください。", "子リポジトリを一つ以上選択してください。", "起動時はスキャンのみ。書き込み前に計画を確認してください。", "言語", "テーマ", "ライト", "ダーク", "システム", "子リポジトリ {n} 件", "ログの保存先", "キャッシュ削除は別の機能です。Git の診断とコマンドは原文で表示します。"
],
"fr": [
"Git · dépôts parents/enfants", "Les dépôts parents et enfants au même endroit.", "Choisir un dépôt", "Actualiser", "Dépôt", "Dépôt enfant", "Branche", "Commit actuel", "URL distante", "Enregistré", "Non enregistré", "Modifié", "Non téléchargé", "Propre",
"Aucun dépôt enfant. Choisissez un autre dépôt ou relancez l’analyse.", "Analyser à nouveau", "Opération", "Télécharger les sous-modules", "Aligner les références", "Compléter .gitmodules", "Synchroniser les modules enregistrés ; préserver les modifications et arrêter en cas de conflit.", "Inscrire le commit actuel des enfants sélectionnés dans l’index parent.", "Détecter et enregistrer les enfants indépendants ; préserver les branches et les remotes.", "Inclure les sous-modules descendants", "Suivre le dernier commit distant", "Prévisualiser l’opération", "Confirmer et exécuter", "Annuler la tâche", "Tout sélectionner", "Désélectionner", "Plan d’opération", "Journal d’exécution", "Prêt", "Traitement…", "Opération terminée", "Opération incomplète", "Exécuter ce plan ?", "Vérifiez le plan ci-dessous. Les dépôts sélectionnés seront modifiés ; annuler ne rétablit pas les étapes terminées.", "Une tâche est en cours. Annulez-la et attendez sa fin.", "Sélectionnez au moins un dépôt enfant.", "Ce panneau analyse seulement. Prévisualisez et confirmez toute écriture.", "Langue", "Thème", "Clair", "Sombre", "Système", "{n} dépôts enfants", "Dossier des journaux", "Le nettoyage du cache est séparé. Les diagnostics et commandes Git restent dans leur langue d’origine."
],
"es": [
"Git · repositorios padre/hijo", "Repositorios padre e hijos en un solo lugar.", "Elegir repositorio", "Actualizar", "Repositorio", "Repositorio hijo", "Rama", "Commit actual", "URL remota", "Registrado", "Sin registrar", "Modificado", "Sin descargar", "Limpio",
"No se encontraron repositorios hijos. Elija otro o vuelva a analizar.", "Volver a analizar", "Operación", "Descargar submódulos", "Alinear referencias", "Completar .gitmodules", "Sincroniza módulos registrados; conserva cambios locales y se detiene ante conflictos.", "Registra el commit actual de los hijos elegidos en el índice del padre.", "Descubre y registra hijos independientes; conserva remotos y ramas.", "Incluir submódulos descendientes", "Seguir el último commit de la rama remota", "Vista previa", "Confirmar y ejecutar", "Cancelar tarea", "Seleccionar todo", "Borrar selección", "Plan de operación", "Registro de ejecución", "Listo", "Procesando…", "Operación completada", "Operación incompleta", "¿Ejecutar este plan?", "Revise el plan. Los repositorios elegidos cambiarán; cancelar no revierte los pasos completados.", "Hay una tarea en curso. Cancélela y espere a que termine.", "Seleccione al menos un repositorio hijo.", "Al abrir solo se analiza. Revise y confirme antes de escribir.", "Idioma", "Tema", "Claro", "Oscuro", "Sistema", "{n} repositorios hijos", "Carpeta de registros", "La limpieza de caché es independiente. Los comandos y diagnósticos Git mantienen su texto original."
],
"de": [
"Git · Eltern-/Kind-Repositories", "Übergeordnete und untergeordnete Repositories an einem Ort.", "Repository wählen", "Aktualisieren", "Repository", "Untergeordnetes Repository", "Branch", "Aktueller Commit", "Remote-URL", "Registriert", "Nicht registriert", "Geändert", "Nicht geladen", "Sauber",
"Keine untergeordneten Repositories gefunden. Anderes Repository wählen oder erneut suchen.", "Erneut suchen", "Aktion", "Submodule herunterladen", "Referenzen abgleichen", ".gitmodules ergänzen", "Registrierte Module synchronisieren; lokale Änderungen erhalten, bei Konflikten anhalten.", "Aktuelle Commits der gewählten Kinder im Index des Eltern-Repositorys eintragen.", "Unabhängige Kinder finden und registrieren; Remotes und Branches erhalten.", "Nachgeordnete Submodule einbeziehen", "Neuestem Remote-Commit folgen", "Aktion prüfen", "Bestätigen und ausführen", "Aufgabe abbrechen", "Alle auswählen", "Auswahl aufheben", "Aktionsplan", "Ausführungsprotokoll", "Bereit", "In Bearbeitung…", "Aktion abgeschlossen", "Aktion unvollständig", "Diesen Plan ausführen?", "Prüfen Sie den Plan. Gewählte Repositories werden geändert; Abbrechen macht fertige Schritte nicht rückgängig.", "Eine Aufgabe läuft. Bitte abbrechen und auf das Ende warten.", "Mindestens ein untergeordnetes Repository auswählen.", "Beim Öffnen wird nur geprüft. Schreibzugriffe vorher prüfen und bestätigen.", "Sprache", "Design", "Hell", "Dunkel", "System", "{n} untergeordnete Repositories", "Protokollordner", "Cache-Bereinigung erfolgt separat. Git-Diagnosen und Befehle behalten ihren Originaltext."
],
"ru": [
"Git · родительские/дочерние", "Родительские и дочерние репозитории в одном месте.", "Выбрать репозиторий", "Обновить", "Репозиторий", "Дочерний репозиторий", "Ветка", "Текущий коммит", "Удалённый URL", "Зарегистрирован", "Не зарегистрирован", "Изменён", "Не загружен", "Без изменений",
"Дочерние репозитории не найдены. Выберите другой или повторите поиск.", "Повторить поиск", "Операция", "Загрузить подмодули", "Согласовать ссылки", "Дополнить .gitmodules", "Синхронизация подмодулей с сохранением локальных изменений; остановка при конфликте.", "Запись текущих коммитов выбранных дочерних репозиториев в индекс родительского.", "Поиск и регистрация независимых репозиториев с сохранением веток и адресов.", "Включить вложенные подмодули", "Следовать последнему удалённому коммиту", "Просмотреть план", "Подтвердить и выполнить", "Отменить задачу", "Выбрать всё", "Снять выделение", "План операции", "Журнал выполнения", "Готово", "Обработка…", "Операция завершена", "Операция не завершена", "Выполнить этот план?", "Проверьте план. Выбранные репозитории будут изменены; отмена не откатывает выполненные шаги.", "Задача выполняется. Отмените её и дождитесь завершения.", "Выберите хотя бы один дочерний репозиторий.", "При открытии выполняется только поиск. Перед записью проверьте и подтвердите план.", "Язык", "Тема", "Светлая", "Тёмная", "Системная", "Дочерних репозиториев: {n}", "Папка журналов", "Очистка кэша выполняется отдельно. Команды и диагностика Git показаны в исходном виде."
],
"ko": [
"Git 부모/자식 저장소 관리", "부모 및 자식 저장소 설정을 한곳에서.", "저장소 선택", "새로 고침", "현재 저장소", "자식 저장소 경로", "브랜치", "현재 커밋", "원격 URL", "등록됨", "미등록", "변경 있음", "다운로드 안 됨", "변경 없음",
"자식 저장소가 없습니다. 다른 저장소를 선택하거나 다시 검색하세요.", "다시 검색", "작업", "하위 모듈 다운로드", "부모 참조 맞추기", ".gitmodules 완성", "등록된 모듈을 동기화합니다. 로컬 변경을 보존하고 충돌 시 중지합니다.", "선택한 자식의 현재 커밋을 부모 인덱스에 기록합니다.", "독립 자식 저장소를 찾아 등록하고 원격 및 브랜치를 보존합니다.", "하위 모듈 재귀 처리", "원격 브랜치의 최신 커밋 사용", "작업 미리 보기", "확인 후 실행", "작업 취소", "모두 선택", "선택 해제", "작업 계획", "실행 로그", "준비됨", "처리 중…", "작업 완료", "작업 미완료", "이 계획을 실행할까요?", "아래 계획을 확인하세요. 선택한 저장소가 변경되며 취소해도 완료한 단계는 복구되지 않습니다.", "작업이 실행 중입니다. 취소한 다음 종료될 때까지 기다리세요.", "자식 저장소를 하나 이상 선택하세요.", "열 때는 검색만 합니다. 쓰기 전에 계획을 확인하고 승인하세요.", "언어", "테마", "라이트", "다크", "시스템", "자식 저장소 {n}개", "로그 폴더", "캐시 정리는 별도 도구입니다. Git 진단 및 명령은 원문으로 표시됩니다."
],
"bo": [
"Git ཕ་བུའི་མཛོད་ཁང་དོ་དམ།", "ཕ་བུའི་མཛོད་ཁང་གི་སྒྲིག་འགོད་གཅིག་ཏུ་བསྡུ།", "མཛོད་ཁང་འདེམས།", "གསར་སྒྱུར།", "ད་ལྟའི་མཛོད་ཁང་།", "བུའི་མཛོད་ཁང་གི་ལམ།", "ཡན་ལག", "ད་ལྟའི་འབུལ་བ།", "རྒྱང་རིང་གི་ཁ་བྱང་།", "ཐོ་འགོད་ཟིན།", "ཐོ་འགོད་མེད།", "བསྒྱུར་བཅོས་ཡོད།", "ཕབ་ལེན་མ་བྱས།", "བསྒྱུར་བཅོས་མེད།",
"བུའི་མཛོད་ཁང་མ་རྙེད། གཞན་འདེམས་པའམ་བསྐྱར་འཚོལ་བྱོས།", "བསྐྱར་འཚོལ།", "བྱ་བ།", "ཡན་ལག་ཆུང་ཕབ་ལེན།", "ཕ་བུའི་འབྲེལ་མཐུད་སྒྲིག", ".gitmodules ཁ་སྐོང་།", "ཐོ་འགོད་ཟིན་པ་མཉམ་སྒྱུར། རང་སའི་བསྒྱུར་བཅོས་སྲུང་ཞིང་འགལ་བ་ཡོད་ན་མཚམས་འཇོག", "བུའི་ད་ལྟའི་འབུལ་བ་ཕའི་དཀར་ཆག་ཏུ་འགོད།", "རང་ཚུགས་བུའི་མཛོད་ཁང་བཙལ་ནས་ཐོ་འགོད། ཁ་བྱང་དང་ཡན་ལག་སྲུང་།", "རིམ་འོག་ཡན་ལག་ཚུད་པ།", "རྒྱང་རིང་ཡན་ལག་གི་གསར་ཤོས་འབུལ་བ་རྗེས་འབྲང་།", "བྱ་བའི་འཆར་གཞི་སྔོན་ལྟ།", "ངོས་ལེན་དང་ལག་ལེན།", "བྱ་བ་མཚམས་འཇོག", "ཚང་མ་འདེམས།", "འདེམས་པ་སེལ།", "བྱ་བའི་འཆར་གཞི།", "ལག་ལེན་ཟིན་ཐོ།", "གྲ་སྒྲིག་ཟིན།", "ལས་ཀ་བྱེད་བཞིན།…", "བྱ་བ་གྲུབ།", "བྱ་བ་མ་གྲུབ།", "འཆར་གཞི་འདི་ལག་ལེན་བྱེད་དམ།", "གཤམ་གྱི་འཆར་གཞི་ཞིབ་བཤེར་བྱོས། འདེམས་པའི་མཛོད་ཁང་འགྱུར། མཚམས་བཞག་ཀྱང་གྲུབ་པའི་གོ་རིམ་རང་འགུལ་ཕྱིར་མི་ལོག", "བྱ་བ་བྱེད་བཞིན་ཡོད། མཚམས་བཞག་ནས་མཇུག་སྒྲིལ་བར་སྒུག", "བུའི་མཛོད་ཁང་གཅིག་ཡན་འདེམས།", "སྒོ་འབྱེད་སྐབས་འཚོལ་བཤེར་ཁོ་ན། འབྲི་བའི་སྔོན་ལ་སྔོན་ལྟ་དང་ངོས་ལེན་དགོས།", "སྐད་ཡིག", "བརྗོད་གཞི།", "ཉིན་མོ།", "མཚན་མོ།", "མ་ལག་རྗེས་འབྲང་།", "བུའི་མཛོད་ཁང་ {n}", "ཟིན་ཐོའི་སྣོད།", "གནས་སྐབས་གསོག་འཇོག་གཙང་བཟོ་མེད། Git བརྡ་འཕྲིན་དང་བཀའ་བརྡ་མ་ཡིག་ལྟར་སྟོན།"
],
}
assert set(CATALOGS) == set(LANGUAGES)
assert all(len(values) == len(KEYS) for values in CATALOGS.values()), {
    key: len(values) for key, values in CATALOGS.items() if len(values) != len(KEYS)
}
TRANSLATIONS = {locale: dict(zip(KEYS, values)) for locale, values in CATALOGS.items()}


def translate(locale: str, key: str, **values) -> str:
    """Return a required localized label without silent language fallback."""
    return TRANSLATIONS[locale][key].format(**values)


# Plans are application text, separate from Git's original command diagnostics.
PLAN_KEYS = (
    'yes no unset pending latest pinned download_effect align_effect register_effect '
    'preflight backup limits cancel_effect source_note'
).split()
PLAN_CATALOGS = {
    'zh_CN': [
        '是', '否', '未设置', '执行时核对',
        '模式：跟随远端分支最新提交，只允许快进；本地分叉时停止。',
        '模式：使用父仓 gitlink 固定提交；不回滚现有历史。',
        '下载影响：同步所选已登记子模块；逐仓核对已配置的 Markdown TOC，还原并验证；未配置则跳过。递归开启时包含新下载子模块的后代。',
        '索引影响：仅将所选 path 的父仓 index 项精确更新为下列 HEAD，mode=160000；不暂存其它文件。',
        '登记影响：增量补齐 .gitmodules，保留现有字段；.gitmodules 不自动暂存。所选 path 的 gitlink 写入父仓 index；初始化本地 submodule config，并用 git submodule absorbgitdirs 归集子仓元数据；保留子仓远端和分支。',
        '写入前：重新核对预览 snapshot；仓库状态变化时停止，必须重新预览。',
        '备份：写入前保存 .gitmodules、父子仓 index、local config 与相关元数据状态；实际备份位置写入日志。',
        '边界：不执行 commit、push、reset 或 clean；不自动清理缓存。',
        '取消：已完成步骤保留，不自动回滚；请根据日志和备份检查实际状态。',
        'url 显示 .gitmodules 中的配置值；实际传输来源、地址重写及提交以执行日志为准。',
    ],
    'zh_TW': [
        '是', '否', '未設定', '執行時核對',
        '模式：跟隨遠端分支最新提交，僅允許快轉；本機分歧時停止。',
        '模式：使用父倉 gitlink 固定提交；不回復既有歷史。',
        '下載影響：同步所選已登記子模組；逐倉核對已設定的 Markdown TOC，還原並驗證；未設定則略過。開啟遞迴時包含新下載子模組的後代。',
        '索引影響：僅將所選 path 的父倉 index 項精確更新為下列 HEAD，mode=160000；不暫存其他檔案。',
        '登記影響：增量補齊 .gitmodules，保留既有欄位；.gitmodules 不自動暫存。所選 path 的 gitlink 寫入父倉 index；初始化本機 submodule config，並用 git submodule absorbgitdirs 集中子倉中繼資料；保留遠端與分支。',
        '寫入前：重新核對預覽 snapshot；倉庫狀態變更時停止，必須重新預覽。',
        '備份：寫入前保存 .gitmodules、父子倉 index、local config 與相關中繼資料狀態；實際備份位置記錄於日誌。',
        '邊界：不執行 commit、push、reset 或 clean；不自動清理快取。',
        '取消：已完成步驟保留，不自動還原；請依日誌與備份核對實際狀態。',
        'url 顯示 .gitmodules 中的設定值；實際傳輸來源、位址改寫與提交以執行日誌為準。',
    ],
    'en': [
        'Yes', 'No', 'Unset', 'Checked during execution',
        'Mode: follow the latest remote branch commit by fast-forward only; stop on local divergence.',
        'Mode: use the parent gitlink revision without rolling back existing history.',
        'Download effects: synchronize selected registered submodules. Restore and verify configured Markdown TOC per repository; skip when unconfigured. Recursion includes descendants of newly downloaded submodules.',
        'Index effects: update only each selected path in the parent index to the HEAD shown below, mode=160000. Do not stage other files.',
        'Registration effects: add missing .gitmodules entries while preserving existing fields; leave .gitmodules unstaged. Write selected gitlinks into the parent index, initialize local submodule config, and collect child metadata with git submodule absorbgitdirs. Preserve child remotes and branches.',
        'Before writes: compare the preview snapshot again. Stop if repository state changed and require a new preview.',
        'Backup: save .gitmodules, parent and child indexes, local config and relevant metadata state before writing. The execution log records the actual backup location.',
        'Limits: no commit, push, reset or clean; no cache cleanup.',
        'Cancellation keeps completed steps and does not roll them back. Inspect the actual state using the log and backup.',
        'url is the .gitmodules configuration value. The execution log identifies actual transfer sources, URL rewriting and commits.',
    ],
    'ja': [
        'はい', 'いいえ', '未設定', '実行時に確認',
        'モード：リモート分岐の最新コミットへ早送りのみ。ローカル履歴が分岐していれば停止します。',
        'モード：親の gitlink 固定コミットを使用し、既存の履歴は巻き戻しません。',
        '取得の影響：選択した登録済みサブモジュールを同期します。各リポジトリで設定済み Markdown TOC を復元して検証し、未設定ならスキップします。再帰時は新規取得した子の下位モジュールも含みます。',
        'インデックスへの影響：親の index 内で選択した path のみを以下の HEAD、mode=160000 に更新し、他のファイルはステージしません。',
        '登録の影響：既存フィールドを保持して .gitmodules を補完し、同ファイルは未ステージのままにします。選択した gitlink を親の index に記録し、ローカル submodule config を初期化し、git submodule absorbgitdirs で子のメタデータを集約します。子のリモートと分岐は保持します。',
        '書き込み前：プレビューの snapshot を再確認します。状態が変化していれば停止し、再プレビューが必要です。',
        'バックアップ：書き込み前に .gitmodules、親子の index、local config と関連メタデータの状態を保存します。保存先は実行ログに表示します。',
        '範囲：commit、push、reset、clean を実行せず、キャッシュも削除しません。',
        '中止しても完了した手順は残り、自動で元に戻りません。ログとバックアップで実際の状態を確認してください。',
        'url は .gitmodules の設定値です。実際の取得元、URL 書き換え、コミットは実行ログで確認します。',
    ],
    'fr': [
        'Oui', 'Non', 'Non défini', 'Vérifié pendant l’exécution',
        'Mode : suivre le dernier commit distant uniquement par avance rapide ; arrêter si l’historique local diverge.',
        'Mode : utiliser le commit fixé par le gitlink parent sans revenir en arrière dans l’historique.',
        'Téléchargement : synchroniser les sous-modules enregistrés sélectionnés. Restaurer et vérifier le Markdown TOC configuré dans chaque dépôt ; ignorer sinon. La récursion inclut les descendants des nouveaux sous-modules.',
        'Index : mettre à jour uniquement chaque path sélectionné dans l’index parent vers le HEAD indiqué, mode=160000 ; ne pas indexer d’autres fichiers.',
        'Enregistrement : compléter .gitmodules en préservant les champs existants et sans indexer ce fichier. Écrire les gitlinks sélectionnés dans l’index parent, initialiser le submodule config local et regrouper les métadonnées enfants avec git submodule absorbgitdirs. Préserver les branches et les remotes enfants.',
        'Avant écriture : comparer à nouveau le snapshot du plan. Si l’état a changé, arrêter et demander un nouveau plan.',
        'Sauvegarde : préserver .gitmodules, les index parents et enfants, local config et les métadonnées concernées avant écriture. Le journal indique l’emplacement réel.',
        'Limites : aucun commit, push, reset ou clean ; aucun nettoyage du cache.',
        'L’annulation conserve les étapes terminées sans les inverser. Vérifiez l’état réel avec le journal et la sauvegarde.',
        'url désigne la valeur dans .gitmodules. Le journal indique les sources de transfert réelles, les réécritures d’URL et les commits.',
    ],
    'es': [
        'Sí', 'No', 'Sin definir', 'Se verifica al ejecutar',
        'Modo: seguir el último commit remoto solo mediante avance rápido; detenerse si el historial local diverge.',
        'Modo: usar el commit fijado por el gitlink del padre sin retroceder en el historial.',
        'Descarga: sincronizar los submódulos registrados seleccionados. Restaurar y verificar el Markdown TOC configurado en cada repositorio; omitirlo si no está configurado. La recursión incluye descendientes de submódulos recién descargados.',
        'Índice: actualizar solo cada path seleccionado en el index del padre al HEAD mostrado, mode=160000; no preparar otros archivos.',
        'Registro: completar .gitmodules conservando campos existentes y dejarlo sin preparar. Escribir los gitlinks elegidos en el index del padre, inicializar submodule config local y agrupar metadatos hijos con git submodule absorbgitdirs. Conservar remotos y ramas de los hijos.',
        'Antes de escribir: comparar de nuevo el snapshot del plan. Si el estado cambió, detenerse y solicitar otra vista previa.',
        'Copia de seguridad: guardar .gitmodules, los index del padre y los hijos, local config y los metadatos afectados antes de escribir. El registro indica la ubicación real.',
        'Límites: no ejecutar commit, push, reset ni clean; no limpiar la caché.',
        'Cancelar conserva los pasos terminados sin revertirlos. Compruebe el estado real mediante el registro y la copia de seguridad.',
        'url muestra la configuración de .gitmodules. El registro identifica el origen real, las reescrituras de URL y los commits.',
    ],
    'de': [
        'Ja', 'Nein', 'Nicht gesetzt', 'Bei der Ausführung geprüft',
        'Modus: dem neuesten Remote-Commit ausschließlich per Fast-Forward folgen; bei abweichender lokaler Historie anhalten.',
        'Modus: den durch den übergeordneten gitlink festgelegten Commit verwenden, ohne bestehende Historie zurückzusetzen.',
        'Download: gewählte registrierte Submodule synchronisieren. Konfiguriertes Markdown TOC je Repository wiederherstellen und prüfen, sonst überspringen. Rekursion umfasst auch Nachfahren neu geladener Submodule.',
        'Index: nur jeden gewählten path im übergeordneten index auf den angezeigten HEAD mit mode=160000 setzen; keine anderen Dateien vormerken.',
        'Registrierung: .gitmodules ergänzen, vorhandene Felder erhalten und die Datei nicht vormerken. Gewählte gitlinks in den übergeordneten index schreiben, lokalen submodule config initialisieren und Kind-Metadaten mit git submodule absorbgitdirs zusammenführen. Remotes und Branches der Kinder erhalten.',
        'Vor Schreibzugriffen: den snapshot des Plans erneut vergleichen. Bei geändertem Repository-Zustand anhalten und eine neue Vorschau verlangen.',
        'Sicherung: .gitmodules, übergeordnete und untergeordnete index, local config und relevante Metadaten vor dem Schreiben sichern. Der tatsächliche Speicherort steht im Protokoll.',
        'Grenzen: kein commit, push, reset oder clean; keine Cache-Bereinigung.',
        'Ein Abbruch erhält abgeschlossene Schritte und macht sie nicht rückgängig. Tatsächlichen Zustand anhand von Protokoll und Sicherung prüfen.',
        'url zeigt den Wert aus .gitmodules. Das Protokoll nennt tatsächliche Übertragungsquellen, URL-Umschreibungen und Commits.',
    ],
    'ru': [
        'Да', 'Нет', 'Не задано', 'Проверяется при выполнении',
        'Режим: следовать последнему удалённому коммиту только быстрым продвижением; при расхождении локальной истории остановиться.',
        'Режим: использовать коммит, закреплённый родительским gitlink, без отката существующей истории.',
        'Загрузка: синхронизировать выбранные зарегистрированные подмодули. В каждом репозитории восстановить и проверить настроенный Markdown TOC, иначе пропустить. Рекурсия включает потомков вновь загруженных подмодулей.',
        'Индекс: обновить только выбранные path в родительском index до показанного HEAD, mode=160000; не добавлять другие файлы.',
        'Регистрация: дополнить .gitmodules с сохранением полей и не добавлять сам файл в индекс. Записать выбранные gitlink в родительский index, инициализировать локальный submodule config и собрать метаданные детей через git submodule absorbgitdirs. Сохранить удалённые адреса и ветки детей.',
        'Перед записью: повторно сравнить snapshot плана. Если состояние изменилось, остановиться и потребовать новый просмотр.',
        'Резервная копия: перед записью сохранить .gitmodules, родительский и дочерние index, local config и соответствующие метаданные. Журнал указывает фактическое расположение.',
        'Границы: не выполнять commit, push, reset или clean; не очищать кэш.',
        'Отмена сохраняет завершённые шаги и не откатывает их. Проверьте фактическое состояние по журналу и резервной копии.',
        'url показывает значение из .gitmodules. Журнал указывает фактические источники передачи, преобразования URL и коммиты.',
    ],
    'ko': [
        '예', '아니요', '설정 안 됨', '실행 시 확인',
        '모드: 원격 최신 커밋을 빠른 이동으로만 적용하며 로컬 기록이 갈라지면 중지합니다.',
        '모드: 부모 gitlink가 고정한 커밋을 사용하며 기존 기록을 되돌리지 않습니다.',
        '다운로드 영향: 선택한 등록 하위 모듈을 동기화합니다. 각 저장소에 설정된 Markdown TOC를 복원하고 검증하며 설정이 없으면 건너뜁니다. 재귀에는 새로 받은 모듈의 하위 모듈도 포함됩니다.',
        '인덱스 영향: 부모 index에서 선택한 path만 아래 HEAD와 mode=160000으로 갱신하며 다른 파일은 스테이징하지 않습니다.',
        '등록 영향: 기존 필드를 유지하며 .gitmodules를 보완하고 이 파일은 스테이징하지 않습니다. 선택한 gitlink를 부모 index에 기록하고 로컬 submodule config를 초기화하며 git submodule absorbgitdirs로 자식 메타데이터를 모읍니다. 자식 원격과 브랜치는 유지합니다.',
        '쓰기 전: 미리 보기의 snapshot을 다시 비교합니다. 저장소 상태가 바뀌면 중지하며 다시 미리 봐야 합니다.',
        '백업: 쓰기 전에 .gitmodules, 부모와 자식 index, local config 및 관련 메타데이터 상태를 저장합니다. 실제 백업 위치는 실행 로그에 표시됩니다.',
        '범위: commit, push, reset, clean을 실행하지 않으며 캐시를 정리하지 않습니다.',
        '취소해도 완료한 단계는 유지되며 자동으로 되돌리지 않습니다. 로그와 백업을 통해 실제 상태를 확인하세요.',
        'url은 .gitmodules 설정값입니다. 실제 전송 원본, URL 변환 및 커밋은 실행 로그에서 확인합니다.',
    ],
    'bo': [
        'ཡིན།', 'མིན།', 'སྒྲིག་མེད།', 'ལག་ལེན་སྐབས་ཞིབ་བཤེར།',
        'རྣམ་པ། རྒྱང་རིང་གི་འབུལ་བ་གསར་ཤོས་ལ་མདུན་སྐྱོད་ཁོ་ན་བྱེད། རང་སའི་ལོ་རྒྱུས་ཁ་གྱེས་ན་མཚམས་འཇོག',
        'རྣམ་པ། ཕའི་ gitlink གི་འབུལ་བ་གཏན་འཁེལ་བ་སྤྱོད། ཡོད་པའི་ལོ་རྒྱུས་ཕྱིར་མི་སློག',
        'ཕབ་ལེན་གྱི་ཤུགས་རྐྱེན། འདེམས་པའི་ཐོ་འགོད་ཟིན་པའི་ཡན་ལག་ཆུང་མཉམ་སྒྱུར། མཛོད་ཁང་རེའི་ Markdown TOC སྒྲིག་ཡོད་ན་སླར་གསོ་དང་ཞིབ་བཤེར། མེད་ན་བརྒལ། རིམ་འོག་ཚུད་པ་འདེམས་ན་གསར་ཕབ་ཀྱི་བུའི་ཡན་ལག་ཡང་ཚུད།',
        'དཀར་ཆག་གི་ཤུགས་རྐྱེན། ཕའི་ index ནང་འདེམས་པའི་ path ཁོ་ན་གཤམ་གྱི་ HEAD དང་ mode=160000 ལ་བསྒྱུར། ཡིག་ཆ་གཞན་གནས་སྐབས་སུ་མི་འཇོག',
        'ཐོ་འགོད་ཀྱི་ཤུགས་རྐྱེན། .gitmodules ཁ་སྐོང་བྱེད་ཅིང་སྔར་གྱི་ས་ཁོངས་སྲུང་། ཡིག་ཆ་དེ་གནས་སྐབས་སུ་མི་འཇོག འདེམས་པའི་ gitlink ཕའི་ index ལ་འབྲི། རང་སའི་ submodule config འགོ་འཛུགས། git submodule absorbgitdirs ཡིས་བུའི་གཞི་གྲངས་བསྡུ། བུའི་རྒྱང་རིང་ཁ་བྱང་དང་ཡན་ལག་སྲུང་།',
        'འབྲི་བའི་སྔོན། སྔོན་ལྟའི་ snapshot བསྐྱར་དུ་ཞིབ་བཤེར། མཛོད་ཁང་གི་གནས་སྟངས་འགྱུར་ན་མཚམས་འཇོག་ཅིང་སྔོན་ལྟ་གསར་པ་དགོས།',
        'འདྲ་བཤུས་ཉར་ཚགས། འབྲི་བའི་སྔོན་ .gitmodules དང་ཕ་བུའི་ index དང་ local config དང་འབྲེལ་ཡོད་གཞི་གྲངས་ཉར། ཉར་སའི་ལམ་ངོ་མ་ཟིན་ཐོར་སྟོན།',
        'མཚམས། commit དང་ push དང་ reset དང་ clean མི་བྱེད། གནས་སྐབས་གསོག་འཇོག་གཙང་མི་བཟོ།',
        'མཚམས་བཞག་ཀྱང་གྲུབ་པའི་གོ་རིམ་སྲུང་ཞིང་རང་འགུལ་ཕྱིར་མི་སློག ཟིན་ཐོ་དང་འདྲ་བཤུས་ལྟར་གནས་སྟངས་ངོ་མ་ཞིབ་བཤེར་བྱོས།',
        'url ནི་ .gitmodules ནང་གི་སྒྲིག་འགོད་ཡིན། ཕབ་ལེན་གྱི་ཁུངས་ངོ་མ་དང་ཁ་བྱང་བསྒྱུར་བ་དང་འབུལ་བ་ཟིན་ཐོར་སྟོན།',
    ],
}
assert set(PLAN_CATALOGS) == set(LANGUAGES)
assert all(len(values) == len(PLAN_KEYS) for values in PLAN_CATALOGS.values())
PLAN_TRANSLATIONS = {
    locale: dict(zip(PLAN_KEYS, values)) for locale, values in PLAN_CATALOGS.items()
}


def render_plan(plan, locale: str) -> str:
    """Describe reviewed data and exact write effects in the selected language."""
    from .git_service import redact

    text = PLAN_TRANSLATIONS[locale]
    t = lambda key: translate(locale, key)
    lines = [f'{t("repository")}: {plan.root}', f'{t("action")}: {t(plan.action)}',
             t(plan.action + '_desc'), '']
    if plan.action == 'download':
        lines += [f'{t("recursive")}: {text["yes" if plan.recursive else "no"]}',
                  f'{t("remote")}: {text["yes" if plan.remote else "no"]}',
                  text['latest' if plan.remote else 'pinned'], text['download_effect']]
    else:
        lines.append(text[plan.action + '_effect'])
    lines.append('')
    for path in plan.paths:
        entry = plan.entries.get(path, {})
        branch = entry.get('branch') or text['unset' if 'branch' in entry else 'pending']
        url = redact(entry['url']) if entry.get('url') else text['pending']
        head = entry.get('head') or text['pending']
        lines += [f'• {t("path")}: {path}', f'  {t("branch")}: {branch}',
                  f'  .gitmodules url: {url}', f'  HEAD: {head}']
        remote_name = entry.get('remote_name') or entry.get('remote')
        if remote_name:
            if remote_name == '(initialize from parent configuration)':
                remote_name = text['pending']
            lines.append(f'  remote: {remote_name}')
        if entry.get('source_url'):
            lines.append(f'  {t("url")}: {redact(entry["source_url"])}')
    lines += ['', text['preflight'], text['backup'], text['limits'], text['cancel_effect']]
    if plan.action == 'download':
        lines += ['', text['source_note']]
    return '\n'.join(lines)
