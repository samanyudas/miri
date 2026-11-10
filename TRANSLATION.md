# Translating Miri

Miri shows its interface in the Mac's language when a translation exists, and in English otherwise ([#350](https://github.com/samanyudas/miri/issues/350)).
This file says how to draft and review a translation, and holds the glossary for each language.
Xcode 27 reads it as context when it drafts a translation.

## Where the text lives

Every interface text is in one string catalog, [Localization/Localizable.xcstrings](Localization/Localizable.xcstrings).
Each key is the English text as it stands in the Swift code, so a change to the English text makes a new key that has no translation yet.
`make strings-update` adds new keys and removes keys that the code no longer uses.
`make strings`, which `make native` and CI run, fails when a key lacks a translation in any of the languages below.
The list of languages lives in `LANGUAGES` in [scripts/check-strings.py](scripts/check-strings.py).

| Code | Language | Code | Language |
| --- | --- | --- | --- |
| `en` | English | `it` | Italian |
| `zh-Hans` | Simplified Chinese | `ru` | Russian |
| `zh-Hant` | Traditional Chinese | `ar` | Arabic |
| `es` | Spanish | `hi` | Hindi |
| `fr` | French | `nl` | Dutch |
| `de` | German | `tr` | Turkish |
| `ja` | Japanese | `pl` | Polish |
| `ko` | Korean | `id` | Indonesian |
| `pt-BR` | Brazilian Portuguese | `vi` | Vietnamese |
| `pt-PT` | European Portuguese | `th` | Thai |
| `uk` | Ukrainian | `sv` | Swedish |

## Add or change interface text

A change that adds or edits interface text also adds its translation in every language above.

1. Change the English text in the Swift code.
2. Run `make strings-update`.
3. Draft the translation of each new key, in every language, with the rules below.
   An AI model may draft it.
   Mark each draft `needs_review`, as Xcode's **Mark as Needs Review** does.
4. Have a second model, or a person who reads the language, check the draft against the glossary.
5. Run `make strings`.

A native speaker who reviews a translation marks it `translated`.
A draft that no native speaker has reviewed yet still ships, and does not fail `make strings`.

## Rules for every language

- Keep every placeholder, such as `%@`, `%lld`, or `%d`, with the same type and count as the English text.
  When the words change order, number them, such as `%1$@` and `%2$@`.
- Keep a space at the start or end of the text.
  Some texts, such as `Note: ` and `Keypad `, are joined to other text in the code.
- Keep these as they are: the name Miri, the shortcut symbols ⌃ ⌥ ⇧ ⌘, and code words such as `miri.strip_gesture`, `options.stack_limit`, `"off"`, `"left"`, `bindings`, `TOML`, `UTF-8`, `ctrl`, `alt`, `cmd`, `leftarrow`, and `fn`.
  The Copy Diagnostics report also keeps its Markdown marks, such as `## `, `### `, and `- `.
- Name a macOS setting, shortcut, or menu command exactly as macOS shows it in that language.
  The glossary below lists the names that Miri uses.
  A path such as `System Settings > Desktop & Dock > Windows` keeps its ` > ` marks between the translated names.
- Keep left, right, above, and below as the screen's real directions, also in Arabic.
  "Focus column left" moves focus to the left on the screen in every language.
- Keep the ellipsis `…` where the English text has it.
  It marks a command that opens a window or asks a question first.
- Use the quotation marks of the language, such as « » in French or „ “ in German.
- Use the register and words that macOS itself uses in that language, such as _du_ in German and _vous_ in French.
- Keep the text about as short as the English text where the language allows.
  Settings wraps long text, but a short label reads faster.
- Never use the em dash.

## Glossary

The macOS names in each table come from macOS 27's own translations in System Settings.
The Miri terms are the words that each translation uses for Miri's own ideas.
[GLOSSARY.md](GLOSSARY.md) defines the English terms.

| English | Meaning |
| --- | --- |
| Miri | The app's name. Never translate it. |
| engine | The program inside Miri that arranges windows. |
| strip | The row of columns on one display and Space, which scrolls left and right. |
| column | One place in a strip. It holds one window, or a stack of windows. |
| stack | Two or more windows on top of each other in one column. |
| display | A physical screen. Use the word that macOS uses for Displays in System Settings. |
| Space | A macOS desktop from Mission Control. Use the word that macOS uses for it. |
| focus | The window that takes the keyboard. "Focus column left" moves focus, not a window. |
| float | A window that floats sits above the strip, outside its columns. |
| strip swipe | The trackpad swipe that scrolls the strip. |
| shortcut | A keyboard shortcut. Use the word that macOS uses in Keyboard Shortcuts. |
| window management | What Miri does while it runs: arranging windows. |
| configuration file | The file `config.toml` that holds Miri's settings and shortcuts. |

## Glossary by language

The first rows are Miri's terms in each translation, and the rows from System Settings on are macOS's own names.

### Simplified Chinese (`zh-Hans`)

| English | Simplified Chinese |
| --- | --- |
| engine | 引擎 |
| strip | 条带 |
| column | 列 |
| stack | 堆叠 |
| display | 显示器 |
| Space | 空间 |
| focus | 焦点 |
| float | 浮动 |
| strip swipe | 条带轻扫 |
| gesture test | 手势测试 |
| shortcut | 快捷键 |
| window management | 窗口管理 |
| configuration file | 配置文件 |
| preset widths | 预设宽度 |
| Setup | 准备工作 |
| General | 通用 |
| Layout | 布局 |
| Shortcuts | 快捷键 |
| Gestures | 手势 |
| Diagnostics | 诊断 |
| System Settings | 系统设置 |
| Desktop & Dock | 桌面与程序坞 |
| Windows | 窗口 |
| Drag windows to left or right edge of screen to tile | 拖移窗口至屏幕左或右边缘实现平铺 |
| Drag windows to menu bar to fill screen | 拖移窗口至菜单栏以充满屏幕 |
| Hold ⌥ key while dragging windows to tile | 拖移窗口时按住⌥键实现平铺 |
| Stage Manager | 台前调度 |
| Mission Control | 调度中心 |
| Displays have separate Spaces | 显示器具有单独空间 |
| Dock | 程序坞 |
| Displays | 显示器 |
| Trackpad | 触控板 |
| More Gestures | 更多手势 |
| Swipe between full-screen applications | 轻扫切换全屏显示应用程序 |
| Swipe between pages | 轻扫切换页面 |
| Accessibility | 无障碍 |
| Pointer Control | 指针控制 |
| Trackpad Options | 触控板选项 |
| Three Finger Drag | 三指拖移 |
| Reduce Motion | 减弱动态效果 |
| Privacy & Security | 隐私与安全 |
| Screen & System Audio Recording | 录屏与系统录音 |
| Device Control and Data Access | 设备控制和数据访问 |
| Keyboard | 键盘 |
| Keyboard Shortcuts | 键盘快捷键 |

### Traditional Chinese (`zh-Hant`)

| English | Traditional Chinese |
| --- | --- |
| engine | 引擎 |
| strip | 條帶 |
| column | 欄 |
| stack | 堆疊 |
| display | 顯示器 |
| Space | 空間 |
| focus | 焦點 |
| float | 浮動 |
| strip swipe | 條帶滑動 |
| gesture test | 手勢測試 |
| shortcut | 快速鍵 |
| window management | 視窗管理 |
| configuration file | 設定檔 |
| preset widths | 預設寬度 |
| Setup | 準備工作 |
| General | 一般 |
| Layout | 佈局 |
| Shortcuts | 快速鍵 |
| Gestures | 手勢 |
| Diagnostics | 診斷 |
| System Settings | 系統設定 |
| Desktop & Dock | 桌面與Dock |
| Windows | 視窗 |
| Drag windows to left or right edge of screen to tile | 將視窗拖移至螢幕左側或右側邊緣來並排 |
| Drag windows to menu bar to fill screen | 拖移視窗至選單列來填滿螢幕 |
| Hold ⌥ key while dragging windows to tile | 拖移視窗並排時按住⌥鍵 |
| Stage Manager | 幕前調度 |
| Mission Control | 指揮中心 |
| Displays have separate Spaces | 顯示器有單獨空間 |
| Dock | Dock |
| Displays | 顯示器 |
| Trackpad | 觸控式軌跡板 |
| More Gestures | 更多手勢 |
| Swipe between full-screen applications | 在全螢幕應用程式之間滑動 |
| Swipe between pages | 在頁面之間滑動 |
| Accessibility | 輔助使用 |
| Pointer Control | 指標控制 |
| Trackpad Options | 觸控式軌跡板選項⋯ |
| Three Finger Drag | 三指拖移 |
| Reduce Motion | 減少動態效果 |
| Privacy & Security | 隱私權與安全性 |
| Screen & System Audio Recording | 螢幕與系統錄音 |
| Device Control and Data Access | 裝置控制和資料取用 |
| Keyboard | 鍵盤 |
| Keyboard Shortcuts | 鍵盤快速鍵⋯ |

### Spanish (`es`)

| English | Spanish |
| --- | --- |
| engine | motor |
| strip | tira |
| column | columna |
| stack | pila |
| display | pantalla |
| Space | Space |
| focus | activar (ventana, columna o pantalla activa) |
| float | flotante |
| strip swipe | deslizamiento de la tira |
| gesture test | prueba del gesto |
| shortcut | atajo |
| window management | gestión de ventanas |
| configuration file | archivo de configuración |
| preset widths | anchos predefinidos |
| Setup | Configuración |
| General | General |
| Layout | Disposición |
| Shortcuts | Atajos |
| Gestures | Gestos |
| Diagnostics | Diagnóstico |
| System Settings | Ajustes del Sistema |
| Desktop & Dock | Escritorio y Dock |
| Windows | Ventanas |
| Drag windows to left or right edge of screen to tile | Arrastrar ventanas al borde izquierdo o derecho de la pantalla para ajustarlas |
| Drag windows to menu bar to fill screen | Arrastrar ventanas a la barra de menús para llenar la pantalla |
| Hold ⌥ key while dragging windows to tile | Ajustar las ventanas manteniendo pulsada la tecla ⌥ al arrastrarlas |
| Stage Manager | Organizador visual |
| Mission Control | Mission Control |
| Displays have separate Spaces | Pantallas con Spaces separados |
| Dock | Dock |
| Displays | Pantallas |
| Trackpad | Trackpad |
| More Gestures | Más gestos |
| Swipe between full-screen applications | Cambiar entre aplicaciones a pantalla completa |
| Swipe between pages | Pasar de página |
| Accessibility | Accesibilidad |
| Pointer Control | Control del puntero |
| Trackpad Options | Opciones del trackpad |
| Three Finger Drag | Arrastrar con 3 dedos |
| Reduce Motion | Reducir movimiento |
| Privacy & Security | Privacidad y seguridad |
| Screen & System Audio Recording | Grabación de pantalla y del audio del sistema |
| Device Control and Data Access | Control de dispositivos y acceso a datos |
| Keyboard | Teclado |
| Keyboard Shortcuts | Atajos de teclado |

### French (`fr`)

| English | French |
| --- | --- |
| engine | moteur |
| strip | bande |
| column | colonne |
| stack | pile |
| display | moniteur |
| Space | Space |
| focus | activer (fenêtre, colonne ou moniteur actif) |
| float | flottante |
| strip swipe | balayage de bande |
| gesture test | test du geste |
| shortcut | raccourci |
| window management | gestion des fenêtres |
| configuration file | fichier de configuration |
| preset widths | largeurs prédéfinies |
| Setup | Configuration |
| General | Général |
| Layout | Disposition |
| Shortcuts | Raccourcis |
| Gestures | Gestes |
| Diagnostics | Diagnostic |
| System Settings | Réglages Système |
| Desktop & Dock | Bureau et Dock |
| Windows | Fenêtres |
| Drag windows to left or right edge of screen to tile | Faire glisser les fenêtres vers le bord gauche ou droit de l’écran pour créer une mosaïque |
| Drag windows to menu bar to fill screen | Faire glisser les fenêtres sur la barre des menus pour occuper tout l’écran |
| Hold ⌥ key while dragging windows to tile | Maintenir la touche ⌥ enfoncée tout en faisant glisser les fenêtres pour les disposer en mosaïque |
| Stage Manager | Stage Manager |
| Mission Control | Mission Control |
| Displays have separate Spaces | Les écrans disposent de Spaces distincts |
| Dock | Dock |
| Displays | Moniteurs |
| Trackpad | Trackpad |
| More Gestures | Gestes supplémentaires |
| Swipe between full-screen applications | Balayer entre les applications en plein écran |
| Swipe between pages | Balayer entre les pages |
| Accessibility | Accessibilité |
| Pointer Control | Contrôle du pointeur |
| Trackpad Options | Options du trackpad |
| Three Finger Drag | Faire glisser avec 3 doigts |
| Reduce Motion | Réduire les animations |
| Privacy & Security | Confidentialité et sécurité |
| Screen & System Audio Recording | Enregistrement de l’écran et des sons du système |
| Device Control and Data Access | Contrôle de l’appareil et accès aux données |
| Keyboard | Clavier |
| Keyboard Shortcuts | Raccourcis clavier |

### German (`de`)

| English | German |
| --- | --- |
| engine | Engine |
| strip | Streifen |
| column | Spalte |
| stack | Stapel |
| display | Display |
| Space | Space |
| focus | Fokus |
| float | schweben |
| strip swipe | Streifengeste |
| gesture test | Gestentest |
| shortcut | Kurzbefehl |
| window management | Fensterverwaltung |
| configuration file | Konfigurationsdatei |
| preset widths | Breitenvorgaben |
| Setup | Einrichtung |
| General | Allgemein |
| Layout | Layout |
| Shortcuts | Kurzbefehle |
| Gestures | Gesten |
| Diagnostics | Diagnose |
| System Settings | Systemeinstellungen |
| Desktop & Dock | Schreibtisch & Dock |
| Windows | Fenster |
| Drag windows to left or right edge of screen to tile | Fenster zum Anordnen an Bildschirmrand ziehen |
| Drag windows to menu bar to fill screen | Fenster für Vollbild in Menüleiste ziehen |
| Hold ⌥ key while dragging windows to tile | Option-Taste (⌥) während des Ziehens von Fenstern gedrückt halten, um Fenster als Kacheln anzuzeigen |
| Stage Manager | Stage Manager |
| Mission Control | Mission Control |
| Displays have separate Spaces | Monitore verwenden verschiedene Spaces |
| Dock | Dock |
| Displays | Displays |
| Trackpad | Trackpad |
| More Gestures | Weitere Gesten |
| Swipe between full-screen applications | Mit Streichen Vollbild-Apps wechseln |
| Swipe between pages | Mit Streichen Seiten blättern |
| Accessibility | Bedienungshilfen |
| Pointer Control | Zeigersteuerung |
| Trackpad Options | Trackpad-Optionen |
| Three Finger Drag | Mit drei Fingern bewegen |
| Reduce Motion | Bewegung reduzieren |
| Privacy & Security | Datenschutz & Sicherheit |
| Screen & System Audio Recording | Aufnahme von Bildschirm & Systemaudio |
| Device Control and Data Access | Gerätesteuerung und Datenzugriff |
| Keyboard | Tastatur |
| Keyboard Shortcuts | Tastaturkurzbefehle |

### Japanese (`ja`)

| English | Japanese |
| --- | --- |
| engine | エンジン |
| strip | ストリップ |
| column | 列 |
| stack | スタック |
| display | ディスプレイ |
| Space | 操作スペース |
| focus | フォーカス |
| float | フロート |
| strip swipe | ストリップのスワイプ |
| gesture test | ジェスチャテスト |
| shortcut | ショートカット |
| window management | ウインドウ管理 |
| configuration file | 設定ファイル |
| preset widths | プリセット幅 |
| Setup | セットアップ |
| General | 一般 |
| Layout | レイアウト |
| Shortcuts | ショートカット |
| Gestures | ジェスチャ |
| Diagnostics | 診断 |
| System Settings | システム設定 |
| Desktop & Dock | デスクトップとDock |
| Windows | ウインドウ |
| Drag windows to left or right edge of screen to tile | ウインドウを画面の左端または右端にドラッグしてタイル表示 |
| Drag windows to menu bar to fill screen | ウインドウをメニューバーにドラッグしてフルスクリーン表示 |
| Hold ⌥ key while dragging windows to tile | ⌥キーを押しながらドラッグしてタイル表示 |
| Stage Manager | ステージマネージャ |
| Mission Control | Mission Control |
| Displays have separate Spaces | ディスプレイごとに個別の操作スペース |
| Dock | Dock |
| Displays | ディスプレイ |
| Trackpad | トラックパッド |
| More Gestures | その他のジェスチャ |
| Swipe between full-screen applications | フルスクリーンアプリケーション間をスワイプ |
| Swipe between pages | ページ間をスワイプ |
| Accessibility | アクセシビリティ |
| Pointer Control | ポインタコントロール |
| Trackpad Options | トラックパッドオプション |
| Three Finger Drag | 3本指のドラッグ |
| Reduce Motion | 視差効果を減らす |
| Privacy & Security | プライバシーとセキュリティ |
| Screen & System Audio Recording | 画面収録とシステムオーディオ録音 |
| Device Control and Data Access | デバイスの制御とデータへのアクセス |
| Keyboard | キーボード |
| Keyboard Shortcuts | キーボードショートカット |

### Korean (`ko`)

| English | Korean |
| --- | --- |
| engine | 엔진 |
| strip | 스트립 |
| column | 열 |
| stack | 스택 |
| display | 디스플레이 |
| Space | Space |
| focus | 초점 |
| float | 띄우기 |
| strip swipe | 스트립 쓸어넘기기 |
| gesture test | 제스처 테스트 |
| shortcut | 단축키 |
| window management | 윈도우 관리 |
| configuration file | 구성 파일 |
| preset widths | 사전 설정 너비 |
| Setup | 준비 |
| General | 일반 |
| Layout | 레이아웃 |
| Shortcuts | 단축키 |
| Gestures | 제스처 |
| Diagnostics | 진단 |
| System Settings | 시스템 설정 |
| Desktop & Dock | 데스크탑 및 Dock |
| Windows | 윈도우 |
| Drag windows to left or right edge of screen to tile | 화면 왼쪽 또는 오른쪽 가장자리로 윈도우를 드래그하여 배치 |
| Drag windows to menu bar to fill screen | 메뉴 막대로 윈도우를 드래그하여 화면 채우기 |
| Hold ⌥ key while dragging windows to tile | ⌥ 키를 누른 상태로 윈도우를 드래그하여 배치 |
| Stage Manager | 스테이지 매니저 |
| Mission Control | Mission Control |
| Displays have separate Spaces | 각각의 Spaces가 있는 디스플레이 |
| Dock | Dock |
| Displays | 디스플레이 |
| Trackpad | 트랙패드 |
| More Gestures | 추가 제스처 |
| Swipe between full-screen applications | 전체 화면 응용 프로그램 쓸어넘기기 |
| Swipe between pages | 페이지 쓸어넘기기 |
| Accessibility | 손쉬운 사용 |
| Pointer Control | 포인터 제어 |
| Trackpad Options | 트랙패드 옵션 |
| Three Finger Drag | 세 손가락으로 드래그하기 |
| Reduce Motion | 동작 줄이기 |
| Privacy & Security | 개인정보 보호 및 보안 |
| Screen & System Audio Recording | 화면 및 시스템 오디오 녹음 |
| Device Control and Data Access | 기기 제어 및 데이터 접근 |
| Keyboard | 키보드 |
| Keyboard Shortcuts | 키보드 단축키 |

### Brazilian Portuguese (`pt-BR`)

| English | Brazilian Portuguese |
| --- | --- |
| engine | motor |
| strip | faixa |
| column | coluna |
| stack | pilha |
| display | tela |
| Space | Space |
| focus | foco (focar; janela em foco) |
| float | flutuar (flutuação) |
| strip swipe | gesto da faixa |
| gesture test | teste do gesto |
| shortcut | atalho |
| window management | gerenciamento de janelas |
| configuration file | arquivo de configuração |
| preset widths | larguras predefinidas |
| Setup | Configuração |
| General | Geral |
| Layout | Layout |
| Shortcuts | Atalhos |
| Gestures | Gestos |
| Diagnostics | Diagnóstico |
| System Settings | Ajustes do Sistema |
| Desktop & Dock | Mesa e Dock |
| Windows | Janelas |
| Drag windows to left or right edge of screen to tile | Arrastar as janelas para a borda esquerda ou direita da tela para organizá‑las em mosaico |
| Drag windows to menu bar to fill screen | Arrastar janelas para a barra de menus para preencher a tela |
| Hold ⌥ key while dragging windows to tile | Manter a tecla ⌥ pressionada para arrastar as janelas e organizá‑las em mosaico |
| Stage Manager | Organizador Visual |
| Mission Control | Mission Control |
| Displays have separate Spaces | As telas têm Spaces separados |
| Dock | Dock |
| Displays | Telas |
| Trackpad | Trackpad |
| More Gestures | Mais Gestos |
| Swipe between full-screen applications | Alternar entre aplicativos em tela cheia |
| Swipe between pages | Alternar entre páginas |
| Accessibility | Acessibilidade |
| Pointer Control | Controle do Cursor |
| Trackpad Options | Opções do Trackpad |
| Three Finger Drag | Arrastar com Três Dedos |
| Reduce Motion | Reduzir Movimento |
| Privacy & Security | Privacidade e Segurança |
| Screen & System Audio Recording | Gravação do Áudio do Sistema e da Tela |
| Device Control and Data Access | Controle do Dispositivo e Acesso a Dados |
| Keyboard | Teclado |
| Keyboard Shortcuts | Atalhos de Teclado |

### European Portuguese (`pt-PT`)

| English | European Portuguese |
| --- | --- |
| engine | motor |
| strip | faixa |
| column | coluna |
| stack | pilha |
| display | monitor |
| Space | Space |
| focus | foco (focar; janela em foco) |
| float | flutuar (flutuação) |
| strip swipe | gesto da faixa |
| gesture test | teste do gesto |
| shortcut | atalho |
| window management | gestão de janelas |
| configuration file | ficheiro de configuração |
| preset widths | larguras predefinidas |
| Setup | Configuração |
| General | Geral |
| Layout | Disposição |
| Shortcuts | Atalhos |
| Gestures | Gestos |
| Diagnostics | Diagnóstico |
| System Settings | Definições do Sistema |
| Desktop & Dock | Secretária e Dock |
| Windows | Janelas |
| Drag windows to left or right edge of screen to tile | Arrastar janelas para a extremidade esquerda ou direita do ecrã para dispor em mosaico |
| Drag windows to menu bar to fill screen | Arrastar janelas para a barra de menus para que preencham o ecrã |
| Hold ⌥ key while dragging windows to tile | Manter premida a tecla ⌥ ao arrastar as janelas para dispor em mosaico |
| Stage Manager | Stage Manager |
| Mission Control | Mission Control |
| Displays have separate Spaces | Ecrãs têm Spaces diferentes |
| Dock | Dock |
| Displays | Monitores |
| Trackpad | Trackpad |
| More Gestures | Mais gestos |
| Swipe between full-screen applications | Alternar entre aplicações em ecrã completo |
| Swipe between pages | Virar as páginas |
| Accessibility | Acessibilidade |
| Pointer Control | Controlo do cursor |
| Trackpad Options | Opções do trackpad |
| Three Finger Drag | Arrastar com três dedos |
| Reduce Motion | Reduzir movimento |
| Privacy & Security | Privacidade e segurança |
| Screen & System Audio Recording | Gravação do ecrã e de áudio do sistema |
| Device Control and Data Access | Controlo do dispositivo e acesso a dados |
| Keyboard | Teclado |
| Keyboard Shortcuts | Atalhos de teclado |

### Italian (`it`)

| English | Italian |
| --- | --- |
| engine | motore |
| strip | striscia |
| column | colonna |
| stack | pila |
| display | schermo |
| Space | spazio |
| focus | attivare (finestra, colonna o schermo attivo) |
| float | fluttuante |
| strip swipe | scorrimento della striscia |
| gesture test | test del gesto |
| shortcut | scorciatoia |
| window management | gestione delle finestre |
| configuration file | file di configurazione |
| preset widths | larghezze predefinite |
| Setup | Configurazione |
| General | Generali |
| Layout | Disposizione |
| Shortcuts | Scorciatoie |
| Gestures | Gesti |
| Diagnostics | Diagnostica |
| System Settings | Impostazioni di Sistema |
| Desktop & Dock | Scrivania e Dock |
| Windows | Finestre |
| Drag windows to left or right edge of screen to tile | Trascina le finestre verso il bordo sinistro o destro dello schermo per disporle a mosaico |
| Drag windows to menu bar to fill screen | Trascina le finestre verso la barra dei menu per riempire lo schermo |
| Hold ⌥ key while dragging windows to tile | Tieni premuto il tasto ⌥ mentre trascini le finestre per disporle a mosaico |
| Stage Manager | Stage Manager |
| Mission Control | Mission Control |
| Displays have separate Spaces | Gli schermi hanno spazi separati |
| Dock | Dock |
| Displays | Schermi |
| Trackpad | Trackpad |
| More Gestures | Altre azioni |
| Swipe between full-screen applications | Scorri tra le applicazioni a tutto schermo |
| Swipe between pages | Scorri tra le pagine |
| Accessibility | Accessibilità |
| Pointer Control | Controllo puntatore |
| Trackpad Options | Opzioni trackpad |
| Three Finger Drag | Trascina con tre dita |
| Reduce Motion | Riduci movimento |
| Privacy & Security | Privacy e sicurezza |
| Screen & System Audio Recording | Registrazione schermo e audio di sistema |
| Device Control and Data Access | Controllo del dispositivo e accesso ai dati |
| Keyboard | Tastiera |
| Keyboard Shortcuts | Scorciatoie da tastiera |

### Russian (`ru`)

| English | Russian |
| --- | --- |
| engine | движок |
| strip | лента |
| column | колонка |
| stack | стопка |
| display | дисплей |
| Space | пространство |
| focus | фокус |
| float | плавающее окно |
| strip swipe | смахивание по ленте |
| gesture test | проверка жеста |
| shortcut | сочетание клавиш |
| window management | управление окнами |
| configuration file | файл конфигурации |
| preset widths | заданные ширины |
| Setup | Подготовка |
| General | Основные |
| Layout | Расположение |
| Shortcuts | Сочетания клавиш |
| Gestures | Жесты |
| Diagnostics | Диагностика |
| System Settings | Системные настройки |
| Desktop & Dock | Рабочий стол и Dock |
| Windows | Окна |
| Drag windows to left or right edge of screen to tile | Перетягивать окна к левому или правому краю экрана, чтобы создать плитки |
| Drag windows to menu bar to fill screen | Перетягивать окна к строке меню, чтобы заполнить экран |
| Hold ⌥ key while dragging windows to tile | Создавать плитки при перетягивании окон с нажатой клавишей ⌥ |
| Stage Manager | Постановщик |
| Mission Control | Mission Control |
| Displays have separate Spaces | Дисплеи с разными рабочими пространствами Spaces |
| Dock | Панель Dock |
| Displays | Дисплеи |
| Trackpad | Трекпад |
| More Gestures | Другие жесты |
| Swipe between full-screen applications | Смахивание для перехода между полноэкранными приложениями |
| Swipe between pages | Смахивание между страницами |
| Accessibility | Универсальный доступ |
| Pointer Control | Управление указателем |
| Trackpad Options | Параметры трекпада |
| Three Finger Drag | Перетягивание тремя пальцами |
| Reduce Motion | Уменьшить движение |
| Privacy & Security | Конфиденциальность и безопасность |
| Screen & System Audio Recording | Запись экрана и системного звука |
| Device Control and Data Access | Управление устройством и доступ к данным |
| Keyboard | Клавиатура |
| Keyboard Shortcuts | Сочетания клавиш |

### Arabic (`ar`)

| English | Arabic |
| --- | --- |
| engine | المحرك |
| strip | الشريط |
| column | العمود |
| stack | الرزمة |
| display | شاشة العرض |
| Space | مساحة |
| focus | التركيز |
| float | تعويم (نافذة عائمة) |
| strip swipe | التمرير السريع للشريط |
| gesture test | اختبار الإيماءة |
| shortcut | اختصار |
| window management | إدارة النوافذ |
| configuration file | ملف التكوين |
| preset widths | العروض المعدة مسبقًا |
| Setup | الإعداد |
| General | عام |
| Layout | التخطيط |
| Shortcuts | الاختصارات |
| Gestures | الإيماءات |
| Diagnostics | التشخيص |
| System Settings | إعدادات النظام |
| Desktop & Dock | سطح المكتب وشريط الأيقونات |
| Windows | النوافذ |
| Drag windows to left or right edge of screen to tile | سحب النوافذ إلى حافة الشاشة اليسرى أو اليمنى للتجانب |
| Drag windows to menu bar to fill screen | سحب النوافذ إلى شريط القوائم لملء الشاشة |
| Hold ⌥ key while dragging windows to tile | الضغط مطولًا على مفتاح ⌥ أثناء سحب النوافذ لإنشاء تجانب |
| Stage Manager | منظم الواجهة |
| Mission Control | إدارة المهام |
| Displays have separate Spaces | توجد للشاشات مساحات منفصلة |
| Dock | شريط الأيقونات |
| Displays | شاشات العرض |
| Trackpad | لوحة التعقب |
| More Gestures | المزيد من الإيماءات |
| Swipe between full-screen applications | التبديل بين تطبيقات ملء الشاشة |
| Swipe between pages | التبديل بين الصفحات |
| Accessibility | تسهيلات الاستخدام |
| Pointer Control | التحكم بالمؤشر |
| Trackpad Options | خيارات لوحة التعقب |
| Three Finger Drag | السحب بثلاثة أصابع |
| Reduce Motion | تقليل الحركة |
| Privacy & Security | الخصوصية والأمن |
| Screen & System Audio Recording | تسجيل الشاشة وصوت النظام |
| Device Control and Data Access | التحكم في الأجهزة والوصول إلى البيانات |
| Keyboard | لوحة المفاتيح |
| Keyboard Shortcuts | اختصارات لوحة المفاتيح |

### Hindi (`hi`)

| English | Hindi |
| --- | --- |
| engine | इंजन |
| strip | स्ट्रिप |
| column | कॉलम |
| stack | स्टैक |
| display | डिस्प्ले |
| Space | Space |
| focus | फ़ोकस |
| float | फ़्लोट |
| strip swipe | स्ट्रिप स्वाइप |
| gesture test | जेस्चर टेस्ट |
| shortcut | शॉर्टकट |
| window management | विंडो प्रबंधन |
| configuration file | कॉन्फ़िगरेशन फ़ाइल |
| preset widths | प्रीसेट चौड़ाइयाँ |
| Setup | सेटअप |
| General | सामान्य |
| Layout | लेआउट |
| Shortcuts | शॉर्टकट |
| Gestures | जेस्चर |
| Diagnostics | डायग्नॉस्टिक्स |
| System Settings | सिस्टम सेटिंग |
| Desktop & Dock | डेस्कटॉप और Dock |
| Windows | विंडो |
| Drag windows to left or right edge of screen to tile | टाइल करने के लिए विंडो स्क्रीन के बाएँ या दाएँ किनारे तक ड्रैग करें |
| Drag windows to menu bar to fill screen | स्क्रीन भरने के लिए विंडो मेन्यू बार में ड्रैग करें |
| Hold ⌥ key while dragging windows to tile | विंडोज़ को टाइल तक ड्रैग करते समय ⌥ “की” दबाए रखें |
| Stage Manager | स्टेज मैनेजर |
| Mission Control | Mission Control |
| Displays have separate Spaces | अलग-अलग डिस्प्ले में अलग-अलग Spaces होने चाहिए |
| Dock | Dock |
| Displays | डिस्प्ले |
| Trackpad | ट्रैकपैड |
| More Gestures | अधिक जेस्चर |
| Swipe between full-screen applications | फ़ुल स्क्रीन ऐप्लिकेशन के बीच स्वाइप करें |
| Swipe between pages | पृष्ठों के बीच स्वाइप करें |
| Accessibility | ऐक्सेसिबिलिटी |
| Pointer Control | पॉइंटर कंट्रोल |
| Trackpad Options | ट्रैकपैड विकल्प |
| Three Finger Drag | तीन उँगलियों से ड्रैग |
| Reduce Motion | गति घटाएँ |
| Privacy & Security | गोपनीयता और सुरक्षा |
| Screen & System Audio Recording | स्क्रीन और सिस्टम ऑडियो रिकॉर्डिंग |
| Device Control and Data Access | डिवाइस नियंत्रण और डेटा ऐक्सेस |
| Keyboard | कीबोर्ड |
| Keyboard Shortcuts | कीबोर्ड शॉर्टकट |

### Dutch (`nl`)

| English | Dutch |
| --- | --- |
| engine | engine |
| strip | strook |
| column | kolom |
| stack | stapel |
| display | beeldscherm |
| Space | space |
| focus | focus |
| float | zweven |
| strip swipe | strookgebaar |
| gesture test | gebarentest |
| shortcut | toetscombinatie |
| window management | vensterbeheer |
| configuration file | configuratiebestand |
| preset widths | breedtevoorinstellingen |
| Setup | Configuratie |
| General | Algemeen |
| Layout | Indeling |
| Shortcuts | Toetscombinaties |
| Gestures | Gebaren |
| Diagnostics | Diagnose |
| System Settings | Systeeminstellingen |
| Desktop & Dock | Bureaublad en Dock |
| Windows | Vensters |
| Drag windows to left or right edge of screen to tile | Sleep vensters naar de linker- of rechterrand van het scherm om te plaatsen |
| Drag windows to menu bar to fill screen | Sleep vensters naar menubalk om scherm te vullen |
| Hold ⌥ key while dragging windows to tile | Houd tijdens het slepen de ⌥-toets ingedrukt om vensters te plaatsen |
| Stage Manager | Stage Manager |
| Mission Control | Mission Control |
| Displays have separate Spaces | Beeldschermen hebben afzonderlijke spaces |
| Dock | Dock |
| Displays | Beeldschermen |
| Trackpad | Trackpad |
| More Gestures | Meer gebaren |
| Swipe between full-screen applications | Vegen tussen schermvullende apps |
| Swipe between pages | Vegen tussen pagina's |
| Accessibility | Toegankelijkheid |
| Pointer Control | Aanwijzerbediening |
| Trackpad Options | Trackpadopties |
| Three Finger Drag | Slepen met drie vingers |
| Reduce Motion | Verminder beweging |
| Privacy & Security | Privacy en beveiliging |
| Screen & System Audio Recording | Scherm- en systeemaudio-opname |
| Device Control and Data Access | Apparaatbeheer en gegevenstoegang |
| Keyboard | Toetsenbord |
| Keyboard Shortcuts | Toetscombinaties |

### Turkish (`tr`)

| English | Turkish |
| --- | --- |
| engine | motor |
| strip | şerit |
| column | sütun |
| stack | yığın |
| display | ekran |
| Space | Spaces alanı |
| focus | odak |
| float | yüzdürmek (yüzen pencere) |
| strip swipe | şerit kaydırma |
| gesture test | hareket testi |
| shortcut | kestirme |
| window management | pencere yönetimi |
| configuration file | yapılandırma dosyası |
| preset widths | hazır genişlikler |
| Setup | Kurulum |
| General | Genel |
| Layout | Yerleşim |
| Shortcuts | Kestirmeler |
| Gestures | Hareketler |
| Diagnostics | Tanılama |
| System Settings | Sistem Ayarları |
| Desktop & Dock | Masaüstü ve Dock |
| Windows | Pencereler |
| Drag windows to left or right edge of screen to tile | Döşemek için pencereleri ekranın sol veya sağ kenarına sürükle |
| Drag windows to menu bar to fill screen | Ekranı doldurmak için pencereleri menü çubuğuna sürükle |
| Hold ⌥ key while dragging windows to tile | Pencereleri döşemek için ⌥ tuşunu basılı tutarak sürükle |
| Stage Manager | Sahne Yöneticisi |
| Mission Control | Mission Control |
| Displays have separate Spaces | Ekranların ayrı Spaces alanları olsun |
| Dock | Dock |
| Displays | Ekranlar |
| Trackpad | İzleme Dörtgeni |
| More Gestures | Daha Fazla Hareket |
| Swipe between full-screen applications | Tam ekran uygulamalar arasında kaydır |
| Swipe between pages | Sayfalar arasında kaydır |
| Accessibility | Erişilebilirlik |
| Pointer Control | İmleç Denetimi |
| Trackpad Options | İzleme Dörtgeni Seçenekleri |
| Three Finger Drag | Üç Parmakla Sürükleme |
| Reduce Motion | Hareketi azalt |
| Privacy & Security | Gizlilik ve Güvenlik |
| Screen & System Audio Recording | Ekran ve Sistem Sesi Kaydı |
| Device Control and Data Access | Aygıt Denetimi ve Veri Erişimi |
| Keyboard | Klavye |
| Keyboard Shortcuts | Klavye Kestirmeleri |

### Polish (`pl`)

| English | Polish |
| --- | --- |
| engine | silnik |
| strip | pas |
| column | kolumna |
| stack | stos |
| display | wyświetlacz |
| Space | przestrzeń |
| focus | aktywne okno |
| float | okno pływające |
| strip swipe | przesuwanie pasa |
| gesture test | test gestu |
| shortcut | skrót |
| window management | zarządzanie oknami |
| configuration file | plik konfiguracji |
| preset widths | predefiniowane szerokości |
| Setup | Przygotowanie |
| General | Ogólne |
| Layout | Układ |
| Shortcuts | Skróty |
| Gestures | Gesty |
| Diagnostics | Diagnostyka |
| System Settings | Ustawienia systemowe |
| Desktop & Dock | Biurko i Dock |
| Windows | Okna |
| Drag windows to left or right edge of screen to tile | Dokuj okna, przeciągając je do lewej lub prawej krawędzi ekranu |
| Drag windows to menu bar to fill screen | Maksymalizuj okna, przeciągając je do paska menu |
| Hold ⌥ key while dragging windows to tile | Przytrzymuj ⌥ podczas przeciągania okien, aby je dokować |
| Stage Manager | Stage Manager |
| Mission Control | Mission Control |
| Displays have separate Spaces | Osobne przestrzenie dla wyświetlaczy |
| Dock | Dock |
| Displays | Wyświetlacze |
| Trackpad | Gładzik |
| More Gestures | Więcej gestów |
| Swipe between full-screen applications | Zmiana aplikacji pełnoekranowej przesunięciem |
| Swipe between pages | Zmiana strony przesunięciem |
| Accessibility | Dostępność |
| Pointer Control | Sterowanie wskaźnikiem |
| Trackpad Options | Opcje gładzika |
| Three Finger Drag | Przeciąganie trzema palcami |
| Reduce Motion | Redukuj ruch |
| Privacy & Security | Prywatność i ochrona |
| Screen & System Audio Recording | Nagrywanie ekranu i dźwięku systemowego |
| Device Control and Data Access | Sterowanie urządzeniami i dostęp do danych |
| Keyboard | Klawiatura |
| Keyboard Shortcuts | Skróty klawiszowe |

### Indonesian (`id`)

| English | Indonesian |
| --- | --- |
| engine | mesin |
| strip | lajur |
| column | kolom |
| stack | tumpukan |
| display | layar |
| Space | Space |
| focus | fokus (jendela terfokus) |
| float | mengambang |
| strip swipe | gesek lajur |
| gesture test | tes gerakan |
| shortcut | pintasan |
| window management | pengelolaan jendela |
| configuration file | file konfigurasi |
| preset widths | lebar prasetel |
| Setup | Penyiapan |
| General | Umum |
| Layout | Tata Letak |
| Shortcuts | Pintasan |
| Gestures | Gerakan |
| Diagnostics | Diagnostik |
| System Settings | Pengaturan Sistem |
| Desktop & Dock | Desktop & Dock |
| Windows | Jendela |
| Drag windows to left or right edge of screen to tile | Seret jendela ke tepi kiri atau kanan layar untuk mengotakkan |
| Drag windows to menu bar to fill screen | Seret jendela ke bar menu untuk mengisi layar |
| Hold ⌥ key while dragging windows to tile | Tahan tombol ⌥ selagi menyeret jendela ke kotak |
| Stage Manager | Pengelola Sorotan |
| Mission Control | Mission Control |
| Displays have separate Spaces | Tampilan memiliki Spaces terpisah |
| Dock | Dock |
| Displays | Layar |
| Trackpad | Trackpad |
| More Gestures | Gerakan Lainnya |
| Swipe between full-screen applications | Gesek antaraplikasi layar penuh |
| Swipe between pages | Gesek antarhalaman |
| Accessibility | Aksesibilitas |
| Pointer Control | Kontrol Penunjuk |
| Trackpad Options | Pilihan Trackpad |
| Three Finger Drag | Seret Tiga Jari |
| Reduce Motion | Kurangi gerakan |
| Privacy & Security | Privasi & Keamanan |
| Screen & System Audio Recording | Rekaman Layar & Audio Sistem |
| Device Control and Data Access | Kontrol Perangkat dan Akses Data |
| Keyboard | Papan Ketik |
| Keyboard Shortcuts | Pintasan Papan Ketik |

### Vietnamese (`vi`)

| English | Vietnamese |
| --- | --- |
| engine | bộ máy |
| strip | dải |
| column | cột |
| stack | chồng |
| display | màn hình |
| Space | Space |
| focus | tiêu điểm |
| float | thả nổi |
| strip swipe | vuốt dải |
| gesture test | kiểm tra cử chỉ |
| shortcut | phím tắt |
| window management | quản lý cửa sổ |
| configuration file | tệp cấu hình |
| preset widths | độ rộng đặt sẵn |
| Setup | Thiết lập |
| General | Cài đặt chung |
| Layout | Bố cục |
| Shortcuts | Phím tắt |
| Gestures | Cử chỉ |
| Diagnostics | Chẩn đoán |
| System Settings | Cài đặt hệ thống |
| Desktop & Dock | Màn hình nền & Dock |
| Windows | Cửa sổ |
| Drag windows to left or right edge of screen to tile | Kéo các cửa sổ đến cạnh trái hoặc cạnh phải của màn hình để ghép |
| Drag windows to menu bar to fill screen | Kéo các cửa sổ đến thanh menu để lấp đầy màn hình |
| Hold ⌥ key while dragging windows to tile | Giữ phím ⌥ trong khi kéo các cửa sổ để xếp cạnh nhau |
| Stage Manager | Quản lý màn hình |
| Mission Control | Mission Control |
| Displays have separate Spaces | Màn hình có các Spaces riêng biệt |
| Dock | Dock |
| Displays | Màn hình |
| Trackpad | Bàn di chuột |
| More Gestures | Cử chỉ khác |
| Swipe between full-screen applications | Vuốt giữa các ứng dụng toàn màn hình |
| Swipe between pages | Vuốt giữa các trang |
| Accessibility | Trợ năng |
| Pointer Control | Điều khiển con trỏ |
| Trackpad Options | Tùy chọn Bàn di chuột |
| Three Finger Drag | Kéo bằng ba ngón tay |
| Reduce Motion | Giảm chuyển động |
| Privacy & Security | Quyền riêng tư & Bảo mật |
| Screen & System Audio Recording | Bản ghi âm thanh hệ thống & màn hình |
| Device Control and Data Access | Điều khiển thiết bị và truy cập dữ liệu |
| Keyboard | Bàn phím |
| Keyboard Shortcuts | Phím tắt |

### Thai (`th`)

| English | Thai |
| --- | --- |
| engine | เอนจิน |
| strip | แถว |
| column | คอลัมน์ |
| stack | กองซ้อน |
| display | จอภาพ |
| Space | Space |
| focus | โฟกัส |
| float | ลอย |
| strip swipe | การปัดแถว |
| gesture test | การทดสอบคำสั่งนิ้ว |
| shortcut | ปุ่มลัด |
| window management | การจัดการหน้าต่าง |
| configuration file | ไฟล์การกำหนดค่า |
| preset widths | ความกว้างที่ตั้งไว้ |
| Setup | เตรียมพร้อม |
| General | ทั่วไป |
| Layout | เค้าโครง |
| Shortcuts | ปุ่มลัด |
| Gestures | คำสั่งนิ้ว |
| Diagnostics | การวินิจฉัย |
| System Settings | การตั้งค่าระบบ |
| Desktop & Dock | เดสก์ท็อปและ Dock |
| Windows | หน้าต่าง |
| Drag windows to left or right edge of screen to tile | ลากหน้าต่างไปยังขอบด้านซ้ายหรือขวาของหน้าจอเพื่อจัดเรียง |
| Drag windows to menu bar to fill screen | ลากหน้าต่างไปยังแถบเมนูเพื่อขยายเต็มหน้าจอ |
| Hold ⌥ key while dragging windows to tile | กดปุ่ม ⌥ ค้างไว้ในระหว่างลากหน้าต่างไปยังสี่เหลี่ยมย่อย |
| Stage Manager | ตัวจัดการให้อยู่ตรงกลาง |
| Mission Control | Mission Control |
| Displays have separate Spaces | Space ของจอภาพแยกต่างหาก |
| Dock | Dock |
| Displays | จอภาพ |
| Trackpad | แทร็คแพด |
| More Gestures | คำสั่งนิ้วเพิ่มเติม |
| Swipe between full-screen applications | ปัดระหว่างแอปพลิเคชันในโหมดเต็มหน้าจอ |
| Swipe between pages | ปัดนิ้วระหว่างหน้า |
| Accessibility | การช่วยการเข้าถึง |
| Pointer Control | การควบคุมตัวชี้ |
| Trackpad Options | ตัวเลือกแทร็คแพด |
| Three Finger Drag | ลากด้วยสามนิ้ว |
| Reduce Motion | ลดการเคลื่อนไหว |
| Privacy & Security | ความเป็นส่วนตัวและความปลอดภัย |
| Screen & System Audio Recording | การบันทึกหน้าจอและเสียงระบบ |
| Device Control and Data Access | การควบคุมอุปกรณ์และการเข้าถึงข้อมูล |
| Keyboard | แป้นพิมพ์ |
| Keyboard Shortcuts | ปุ่มลัดแป้นพิมพ์ |

### Ukrainian (`uk`)

| English | Ukrainian |
| --- | --- |
| engine | рушій |
| strip | стрічка |
| column | колонка |
| stack | стос |
| display | дисплей |
| Space | простір |
| focus | фокус |
| float | плаваюче вікно |
| strip swipe | змахування стрічки |
| gesture test | перевірка жесту |
| shortcut | скорочення |
| window management | керування вікнами |
| configuration file | файл конфігурації |
| preset widths | задані ширини |
| Setup | Підготовка |
| General | Загальні |
| Layout | Розташування |
| Shortcuts | Скорочення |
| Gestures | Жести |
| Diagnostics | Діагностика |
| System Settings | Системні параметри |
| Desktop & Dock | Робочий стіл і Dock |
| Windows | Вікна |
| Drag windows to left or right edge of screen to tile | Закріплювати вікна перетягуванням до лівого або правого краю екрана |
| Drag windows to menu bar to fill screen | Розгортати вікна на весь екран перетягуванням до смуги меню |
| Hold ⌥ key while dragging windows to tile | Утримувати клавішу Option (⌥) під час перетягування вікон |
| Stage Manager | Постановник |
| Mission Control | Mission Control |
| Displays have separate Spaces | Окремі Spaces на дисплеях |
| Dock | Dock |
| Displays | Дисплеї |
| Trackpad | Трекпед |
| More Gestures | Інші жести |
| Swipe between full-screen applications | Перехід між повноекранними програмами |
| Swipe between pages | Перехід між сторінками |
| Accessibility | Доступність |
| Pointer Control | Керування вказівником |
| Trackpad Options | Параметри трекпеда |
| Three Finger Drag | Перетягування трьома пальцями |
| Reduce Motion | Зменшити рух |
| Privacy & Security | Приватність і безпека |
| Screen & System Audio Recording | Записування системного звуку й екрана |
| Device Control and Data Access | Керування пристроями й доступ до даних |
| Keyboard | Клавіатура |
| Keyboard Shortcuts | Клавіатурні скорочення |

### Swedish (`sv`)

| English | Swedish |
| --- | --- |
| engine | motor |
| strip | remsa |
| column | kolumn |
| stack | stapel |
| display | bildskärm |
| Space | Space |
| focus | fokus |
| float | flyta |
| strip swipe | remsvep |
| gesture test | gesttest |
| shortcut | kortkommando |
| window management | fönsterhantering |
| configuration file | konfigurationsfil |
| preset widths | förinställda bredder |
| Setup | Konfiguration |
| General | Allmänt |
| Layout | Layout |
| Shortcuts | Kortkommandon |
| Gestures | Gester |
| Diagnostics | Diagnostik |
| System Settings | Systeminställningar |
| Desktop & Dock | Skrivbord och Dock |
| Windows | Fönster |
| Drag windows to left or right edge of screen to tile | Dra fönster till vänstra eller högra kanten av skärmen så att de staplas på varandra |
| Drag windows to menu bar to fill screen | Dra fönster till menyraden så att de fyller skärmen |
| Hold ⌥ key while dragging windows to tile | Håll ned tangenten ⌥ medan du drar fönster om du vill stapla dem på varandra |
| Stage Manager | Blickfång |
| Mission Control | Mission Control |
| Displays have separate Spaces | Bildskärmar har egna Spaces |
| Dock | Dock |
| Displays | Bildskärmar |
| Trackpad | Styrplatta |
| More Gestures | Fler gester |
| Swipe between full-screen applications | Svep mellan appar i helskärmsläge |
| Swipe between pages | Svep mellan sidor |
| Accessibility | Hjälpmedel |
| Pointer Control | Pekarstyrning |
| Trackpad Options | Styrplattealternativ |
| Three Finger Drag | Trefingersdragning |
| Reduce Motion | Minska rörelse |
| Privacy & Security | Integritet och säkerhet |
| Screen & System Audio Recording | Skärm- och systemljudsinspelning |
| Device Control and Data Access | Enhetskontroll och dataåtkomst |
| Keyboard | Tangentbord |
| Keyboard Shortcuts | Kortkommandon |
