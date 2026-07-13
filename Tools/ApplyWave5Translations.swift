#!/usr/bin/env swift
import Foundation

// Machine-assisted Wave 5 seed translations. These release-surface strings are
// deliberately kept in one reviewable map so in-context QA can correct a value
// without touching source code. Run from the repository root:
//   swift Tools/ApplyWave5Translations.swift Tonic/Tonic/Localizable.xcstrings

let values: [String: [String: String]] = [
    "System Health": ["es": "Estado del sistema", "de": "Systemzustand", "fr": "État du système", "ja": "システム状態", "zh-Hans": "系统健康"],
    "Now Playing": ["es": "En reproducción", "de": "Aktuelle Wiedergabe", "fr": "À l’écoute", "ja": "再生中", "zh-Hans": "正在播放"],
    "Recommended": ["es": "Recomendado", "de": "Empfohlen", "fr": "Recommandé", "ja": "おすすめ", "zh-Hans": "推荐"],
    "Weather": ["es": "Tiempo", "de": "Wetter", "fr": "Météo", "ja": "天気", "zh-Hans": "天气"],
    "Clipboard": ["es": "Portapapeles", "de": "Zwischenablage", "fr": "Presse-papiers", "ja": "クリップボード", "zh-Hans": "剪贴板"],
    "Next Event": ["es": "Próximo evento", "de": "Nächster Termin", "fr": "Prochain événement", "ja": "次の予定", "zh-Hans": "下一个日程"],
    "Quick Notes": ["es": "Notas rápidas", "de": "Kurznotizen", "fr": "Notes rapides", "ja": "クイックメモ", "zh-Hans": "快速备忘"],
    "Timers": ["es": "Temporizadores", "de": "Timer", "fr": "Minuteurs", "ja": "タイマー", "zh-Hans": "计时器"],
    "Files": ["es": "Archivos", "de": "Dateien", "fr": "Fichiers", "ja": "ファイル", "zh-Hans": "文件"],
    "Shortcuts": ["es": "Atajos", "de": "Kurzbefehle", "fr": "Raccourcis", "ja": "ショートカット", "zh-Hans": "快捷指令"],
    "Provider Cards": ["es": "Tarjetas de proveedores", "de": "Anbieterkarten", "fr": "Cartes de fournisseurs", "ja": "プロバイダカード", "zh-Hans": "提供方卡片"],
    "Refresh module": ["es": "Actualizar módulo", "de": "Modul aktualisieren", "fr": "Actualiser le module", "ja": "モジュールを更新", "zh-Hans": "刷新模块"],
    "Open link": ["es": "Abrir enlace", "de": "Link öffnen", "fr": "Ouvrir le lien", "ja": "リンクを開く", "zh-Hans": "打开链接"],
    "Open in Tonic": ["es": "Abrir en Tonic", "de": "In Tonic öffnen", "fr": "Ouvrir dans Tonic", "ja": "Tonicで開く", "zh-Hans": "在 Tonic 中打开"],
    "Start timer": ["es": "Iniciar temporizador", "de": "Timer starten", "fr": "Démarrer le minuteur", "ja": "タイマーを開始", "zh-Hans": "启动计时器"],
    "Pause timer": ["es": "Pausar temporizador", "de": "Timer pausieren", "fr": "Mettre le minuteur en pause", "ja": "タイマーを一時停止", "zh-Hans": "暂停计时器"],
    "Remove note": ["es": "Eliminar nota", "de": "Notiz entfernen", "fr": "Supprimer la note", "ja": "メモを削除", "zh-Hans": "删除备忘"],
    "Run Apple Shortcut": ["es": "Ejecutar atajo de Apple", "de": "Apple-Kurzbefehl ausführen", "fr": "Exécuter le raccourci Apple", "ja": "Appleショートカットを実行", "zh-Hans": "运行 Apple 快捷指令"],
    "Play or pause": ["es": "Reproducir o pausar", "de": "Wiedergabe oder Pause", "fr": "Lire ou mettre en pause", "ja": "再生または一時停止", "zh-Hans": "播放或暂停"],
    "Next track": ["es": "Pista siguiente", "de": "Nächster Titel", "fr": "Piste suivante", "ja": "次のトラック", "zh-Hans": "下一曲"],
    "Previous track": ["es": "Pista anterior", "de": "Vorheriger Titel", "fr": "Piste précédente", "ja": "前のトラック", "zh-Hans": "上一曲"],
    "Open recent file": ["es": "Abrir archivo reciente", "de": "Letzte Datei öffnen", "fr": "Ouvrir le fichier récent", "ja": "最近のファイルを開く", "zh-Hans": "打开最近文件"],
    "App and OS": ["es": "App y sistema", "de": "App und System", "fr": "App et système", "ja": "アプリとシステム", "zh-Hans": "App 与系统"],
    "Capability state": ["es": "Estado de capacidades", "de": "Funktionsstatus", "fr": "État des capacités", "ja": "機能の状態", "zh-Hans": "功能状态"],
    "Redacted action receipts": ["es": "Recibos de acciones censurados", "de": "Bereinigte Aktionsbelege", "fr": "Reçus d’actions expurgés", "ja": "編集済みアクション記録", "zh-Hans": "已脱敏的操作收据"],
    "Helper status": ["es": "Estado del asistente", "de": "Hilfsdienststatus", "fr": "État du service privilégié", "ja": "ヘルパーの状態", "zh-Hans": "辅助程序状态"],
    "Provider health": ["es": "Estado de proveedores", "de": "Anbieterstatus", "fr": "État des fournisseurs", "ja": "プロバイダの状態", "zh-Hans": "提供方状态"],
    "Compatibility decisions": ["es": "Decisiones de compatibilidad", "de": "Kompatibilitätsentscheidungen", "fr": "Décisions de compatibilité", "ja": "互換性の判定", "zh-Hans": "兼容性判定"],
    "Bounded recent logs": ["es": "Registros recientes limitados", "de": "Begrenzte aktuelle Protokolle", "fr": "Journaux récents limités", "ja": "制限付き最近のログ", "zh-Hans": "受限的近期日志"],
    "Refresh DNS resolution": ["es": "Actualizar la resolución DNS", "de": "DNS-Auflösung aktualisieren", "fr": "Actualiser la résolution DNS", "ja": "DNS解決を更新", "zh-Hans": "刷新 DNS 解析"],
    "Renew the active network service": ["es": "Renovar el servicio de red activo", "de": "Aktiven Netzwerkdienst erneuern", "fr": "Renouveler le service réseau actif", "ja": "使用中のネットワークサービスを更新", "zh-Hans": "续订当前网络服务"],
    "Rebuild the startup-disk Spotlight index": ["es": "Reconstruir el índice de Spotlight del disco de arranque", "de": "Spotlight-Index des Startvolumes neu erstellen", "fr": "Reconstruire l’index Spotlight du disque de démarrage", "ja": "起動ディスクのSpotlight索引を再構築", "zh-Hans": "重建启动磁盘的 Spotlight 索引"],
    "Rebuild application registration": ["es": "Reconstruir el registro de aplicaciones", "de": "App-Registrierung neu erstellen", "fr": "Reconstruire l’enregistrement des applications", "ja": "アプリ登録を再構築", "zh-Hans": "重建应用注册信息"],
    "Reclaim local Time Machine snapshots": ["es": "Recuperar instantáneas locales de Time Machine", "de": "Lokale Time-Machine-Snapshots freigeben", "fr": "Récupérer les instantanés locaux Time Machine", "ja": "ローカルTime Machineスナップショットを解放", "zh-Hans": "回收本地 Time Machine 快照"],
    "Remove stale document revisions": ["es": "Eliminar revisiones de documentos obsoletas", "de": "Veraltete Dokumentversionen entfernen", "fr": "Supprimer les révisions de documents obsolètes", "ja": "古い書類履歴を削除", "zh-Hans": "移除过期的文稿修订"],
    "No supported playback session": ["es": "No hay una sesión de reproducción compatible", "de": "Keine unterstützte Wiedergabesitzung", "fr": "Aucune session de lecture compatible", "ja": "対応する再生セッションはありません", "zh-Hans": "没有受支持的播放会话"],
    "No urgent action": ["es": "No hay acciones urgentes", "de": "Keine dringende Aktion", "fr": "Aucune action urgente", "ja": "緊急の操作はありません", "zh-Hans": "没有紧急操作"],
    "Calendar access is off": ["es": "El acceso al calendario está desactivado", "de": "Kalenderzugriff ist deaktiviert", "fr": "L’accès au calendrier est désactivé", "ja": "カレンダーへのアクセスはオフです", "zh-Hans": "日历访问已关闭"],
    "No upcoming events": ["es": "No hay próximos eventos", "de": "Keine anstehenden Termine", "fr": "Aucun événement à venir", "ja": "今後の予定はありません", "zh-Hans": "没有即将开始的日程"],
    "No active timers": ["es": "No hay temporizadores activos", "de": "Keine aktiven Timer", "fr": "Aucun minuteur actif", "ja": "作動中のタイマーはありません", "zh-Hans": "没有活动的计时器"],
    "No providers installed": ["es": "No hay proveedores instalados", "de": "Keine Anbieter installiert", "fr": "Aucun fournisseur installé", "ja": "プロバイダはインストールされていません", "zh-Hans": "未安装提供方"]
]

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: ApplyWave5Translations.swift <Localizable.xcstrings>\n".utf8))
    exit(64)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: url)
guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      var strings = root["strings"] as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }

for (key, translations) in values {
    guard var entry = strings[key] as? [String: Any] else {
        FileHandle.standardError.write(Data("missing extracted key: \(key)\n".utf8))
        exit(65)
    }
    var localizations = entry["localizations"] as? [String: Any] ?? [:]
    for (locale, value) in translations {
        localizations[locale] = ["stringUnit": ["state": "translated", "value": value]]
    }
    entry["localizations"] = localizations
    strings[key] = entry
}
root["strings"] = strings
let output = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
try output.write(to: url, options: .atomic)
print("Applied \(values.count) Wave 5 translations across five locales.")
