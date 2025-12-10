import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  String _currentLanguage = 'en';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _cachedUserId;
  bool _isLoading = false;
  
  String get currentLanguage => _currentLanguage;

  // Load language from Firestore - always reload on app start
  Future<void> loadLanguageFromFirestore({bool forceReload = false}) async {
    // Prevent duplicate loading
    if (_isLoading) return;
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Skip if already loaded for this user (unless force reload)
        if (!forceReload && _cachedUserId == user.uid) {
          if (kDebugMode) {
            debugPrint('🌐 [Localization] Using cached language: $_currentLanguage');
          }
          return;
        }
        
        _isLoading = true;
        
        if (kDebugMode) {
          debugPrint('🌐 [Localization] Loading language from Firestore for user: ${user.uid}');
        }
        
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final language = doc.data()?['language'] as String?;
          if (kDebugMode) {
            debugPrint('🌐 [Localization] Language from Firestore: $language');
          }
          
          if (language != null && supportedLanguages.containsKey(language)) {
            _currentLanguage = language;
            _cachedUserId = user.uid;
            
            if (kDebugMode) {
              debugPrint('✅ [Localization] Language set to: $_currentLanguage');
            }
            
            notifyListeners(); // Notify all listeners when language is loaded
          } else {
            if (kDebugMode) {
              debugPrint('⚠️ [Localization] No valid language found, using default: en');
            }
          }
        }
      }
    } catch (e) {
      // If error, keep default language
      if (kDebugMode) {
        debugPrint('❌ [Localization] Error loading language: $e');
      }
    } finally {
      _isLoading = false;
    }
  }
  
  // Reset cache when user signs out
  void resetCache() {
    _cachedUserId = null;
    _currentLanguage = 'en';
    notifyListeners();
  }

  // Supported languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
    'es': 'Español',
    'fr': 'Français',
  };

  // Language flags
  static const Map<String, String> languageFlags = {
    'en': '🇬🇧',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'zh': '🇨🇳',
    'es': '🇪🇸',
    'fr': '🇫🇷',
  };

  Future<void> setLanguage(String languageCode) async {
    if (supportedLanguages.containsKey(languageCode)) {
      _currentLanguage = languageCode;
      notifyListeners(); // Notify all listeners immediately when language changes
      
      // Save to Firestore
      try {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'language': languageCode,
          });
        }
      } catch (e) {
        // If error, language is still set locally
      }
    }
  }

  String translate(String key) {
    return _translations[key]?[_currentLanguage] ?? key;
  }

  // All translations
  static final Map<String, Map<String, String>> _translations = {
    // App Name
    'app_name': {
      'en': 'Callog',
      'ja': 'Callog',
      'ko': 'Callog',
      'zh': 'Callog',
      'es': 'Callog',
      'fr': 'Callog',
    },

    // Authentication
    'login': {
      'en': 'Login',
      'ja': 'ログイン',
      'ko': '로그인',
      'zh': '登录',
      'es': 'Iniciar sesión',
      'fr': 'Connexion',
    },
    'email': {
      'en': 'Email',
      'ja': 'メール',
      'ko': '이메일',
      'zh': '电子邮件',
      'es': 'Correo electrónico',
      'fr': 'E-mail',
    },
    'password': {
      'en': 'Password',
      'ja': 'パスワード',
      'ko': '비밀번호',
      'zh': '密码',
      'es': 'Contraseña',
      'fr': 'Mot de passe',
    },
    'sign_in_with_google': {
      'en': 'Sign in with Google',
      'ja': 'Googleでサインイン',
      'ko': 'Google로 로그인',
      'zh': '使用Google登录',
      'es': 'Iniciar sesión con Google',
      'fr': 'Se connecter avec Google',
    },
    'sign_up': {
      'en': 'Sign Up',
      'ja': '新規登録',
      'ko': '가입하기',
      'zh': '注册',
      'es': 'Registrarse',
      'fr': 'S\'inscrire',
    },
    'login_success': {
      'en': 'Login successful!',
      'ja': 'ログインに成功しました！',
      'ko': '로그인 성공!',
      'zh': '登录成功！',
      'es': '¡Inicio de sesión exitoso!',
      'fr': 'Connexion réussie !',
    },
    'login_failed': {
      'en': 'Login failed',
      'ja': 'ログインに失敗しました',
      'ko': '로그인 실패',
      'zh': '登录失败',
      'es': 'Inicio de sesión fallido',
      'fr': 'Échec de la connexion',
    },

    // Profile Setup
    'profile_setup': {
      'en': 'Profile Setup',
      'ja': 'プロフィール設定',
      'ko': '프로필 설정',
      'zh': '个人资料设置',
      'es': 'Configuración de perfil',
      'fr': 'Configuration du profil',
    },
    'username': {
      'en': 'Username',
      'ja': 'ユーザー名',
      'ko': '사용자 이름',
      'zh': '用户名',
      'es': 'Nombre de usuario',
      'fr': 'Nom d\'utilisateur',
    },
    'location': {
      'en': 'Location',
      'ja': '場所',
      'ko': '위치',
      'zh': '位置',
      'es': 'Ubicación',
      'fr': 'Emplacement',
    },
    'language': {
      'en': 'Language',
      'ja': '言語',
      'ko': '언어',
      'zh': '语言',
      'es': 'Idioma',
      'fr': 'Langue',
    },
    'save': {
      'en': 'Save',
      'ja': '保存',
      'ko': '저장',
      'zh': '保存',
      'es': 'Guardar',
      'fr': 'Enregistrer',
    },

    // Main Feed
    'no_friends': {
      'en': 'No friends yet',
      'ja': '友達がいません',
      'ko': '친구가 없습니다',
      'zh': '暂无好友',
      'es': 'Aún no hay amigos',
      'fr': 'Aucun ami',
    },
    'add_friends': {
      'en': 'Add friends to start chatting',
      'ja': '友達を追加してチャットを始めよう',
      'ko': '친구를 추가하여 채팅을 시작하세요',
      'zh': '添加好友开始聊天',
      'es': 'Agrega amigos para comenzar a chatear',
      'fr': 'Ajouter des amis pour commencer à discuter',
    },
    'add_friend': {
      'en': 'Add Friend',
      'ja': '友達を追加',
      'ko': '친구 추가',
      'zh': '添加好友',
      'es': 'Agregar amigo',
      'fr': 'Ajouter un ami',
    },

    // Search Contacts
    'search_by_username': {
      'en': 'Search by username',
      'ja': 'ユーザー名で検索',
      'ko': '사용자 이름으로 검색',
      'zh': '通过用户名搜索',
      'es': 'Buscar por nombre de usuario',
      'fr': 'Rechercher par nom d\'utilisateur',
    },
    'added_friends': {
      'en': 'Added Friends',
      'ja': '追加された友達',
      'ko': '추가된 친구',
      'zh': '已添加的好友',
      'es': 'Amigos agregados',
      'fr': 'Amis ajoutés',
    },
    'search_results': {
      'en': 'Search Results',
      'ja': '検索結果',
      'ko': '검색 결과',
      'zh': '搜索结果',
      'es': 'Resultados de búsqueda',
      'fr': 'Résultats de recherche',
    },
    'no_users_found': {
      'en': 'No users found',
      'ja': 'ユーザーが見つかりませんでした',
      'ko': '사용자를 찾을 수 없습니다',
      'zh': '未找到用户',
      'es': 'No se encontraron usuarios',
      'fr': 'Aucun utilisateur trouvé',
    },
    'friend_added': {
      'en': 'Friend added',
      'ja': '友達を追加しました',
      'ko': '친구가 추가되었습니다',
      'zh': '已添加好友',
      'es': 'Amigo agregado',
      'fr': 'Ami ajouté',
    },
    'friend_removed': {
      'en': 'Friend removed',
      'ja': '友達を削除しました',
      'ko': '친구가 삭제되었습니다',
      'zh': '已删除好友',
      'es': 'Amigo eliminado',
      'fr': 'Ami supprimé',
    },
    'error_occurred': {
      'en': 'An error occurred',
      'ja': 'エラーが発生しました',
      'ko': '오류가 발생했습니다',
      'zh': '发生错误',
      'es': 'Ocurrió un error',
      'fr': 'Une erreur s\'est produite',
    },
    'add_button': {
      'en': 'Add',
      'ja': '追加',
      'ko': '추가',
      'zh': '添加',
      'es': 'Agregar',
      'fr': 'Ajouter',
    },
    'remove_button': {
      'en': 'Remove',
      'ja': '削除',
      'ko': '삭제',
      'zh': '删除',
      'es': 'Eliminar',
      'fr': 'Supprimer',
    },
    'send_message': {
      'en': 'Send message',
      'ja': 'メッセージを送信',
      'ko': '메시지 보내기',
      'zh': '发送消息',
      'es': 'Enviar mensaje',
      'fr': 'Envoyer un message',
    },
    'no_messages_yet': {
      'en': 'No messages yet',
      'ja': 'まだメッセージがありません',
      'ko': '아직 메시지가 없습니다',
      'zh': '还没有消息',
      'es': 'Aún no hay mensajes',
      'fr': 'Pas encore de messages',
    },
    'start_conversation': {
      'en': 'Start a conversation',
      'ja': '会話を始めましょう',
      'ko': '대화를 시작하세요',
      'zh': '开始对话',
      'es': 'Iniciar una conversación',
      'fr': 'Commencer une conversation',
    },

    // Chat
    'chat': {
      'en': 'Chat',
      'ja': 'チャット',
      'ko': '채팅',
      'zh': '聊天',
      'es': 'Chat',
      'fr': 'Chat',
    },
    'type_message': {
      'en': 'Type a message...',
      'ja': 'メッセージを入力...',
      'ko': '메시지를 입력하세요...',
      'zh': '输入消息...',
      'es': 'Escribe un mensaje...',
      'fr': 'Taper un message...',
    },
    'send': {
      'en': 'Send',
      'ja': '送信',
      'ko': '보내기',
      'zh': '发送',
      'es': 'Enviar',
      'fr': 'Envoyer',
    },

    // Calls
    'voice_call': {
      'en': 'Voice Call',
      'ja': '音声通話',
      'ko': '음성 통화',
      'zh': '语音通话',
      'es': 'Llamada de voz',
      'fr': 'Appel vocal',
    },
    'video_call': {
      'en': 'Video Call',
      'ja': 'ビデオ通話',
      'ko': '영상 통화',
      'zh': '视频通话',
      'es': 'Videollamada',
      'fr': 'Appel vidéo',
    },
    'incoming_call': {
      'en': 'Incoming Call',
      'ja': '着信',
      'ko': '수신 전화',
      'zh': '来电',
      'es': 'Llamada entrante',
      'fr': 'Appel entrant',
    },
    'accept': {
      'en': 'Accept',
      'ja': '応答',
      'ko': '수락',
      'zh': '接受',
      'es': 'Aceptar',
      'fr': 'Accepter',
    },
    'decline': {
      'en': 'Decline',
      'ja': '拒否',
      'ko': '거절',
      'zh': '拒绝',
      'es': 'Rechazar',
      'fr': 'Refuser',
    },
    'end_call': {
      'en': 'End Call',
      'ja': '通話を終了',
      'ko': '통화 종료',
      'zh': '结束通话',
      'es': 'Finalizar llamada',
      'fr': 'Terminer l\'appel',
    },
    'calling': {
      'en': 'Calling...',
      'ja': '呼び出し中...',
      'ko': '전화 거는 중...',
      'zh': '呼叫中...',
      'es': 'Llamando...',
      'fr': 'Appel en cours...',
    },
    'call_connected': {
      'en': 'Connected',
      'ja': '接続中',
      'ko': '연결됨',
      'zh': '已连接',
      'es': 'Conectado',
      'fr': 'Connecté',
    },
    'call_ended': {
      'en': 'Call Ended',
      'ja': '通話終了',
      'ko': '통화 종료',
      'zh': '通话结束',
      'es': 'Llamada finalizada',
      'fr': 'Appel terminé',
    },
    'call_rejected': {
      'en': 'Call Rejected',
      'ja': '通話拒否',
      'ko': '통화 거부됨',
      'zh': '通话被拒绝',
      'es': 'Llamada rechazada',
      'fr': 'Appel rejeté',
    },
    'speaker': {
      'en': 'Speaker',
      'ja': 'スピーカー',
      'ko': '스피커',
      'zh': '扬声器',
      'es': 'Altavoz',
      'fr': 'Haut-parleur',
    },
    'mute': {
      'en': 'Mute',
      'ja': 'ミュート',
      'ko': '음소거',
      'zh': '静音',
      'es': 'Silenciar',
      'fr': 'Muet',
    },
    'slide_to_answer': {
      'en': 'Slide to Answer',
      'ja': 'スライドで応答',
      'ko': '밀어서 응답',
      'zh': '滑动接听',
      'es': 'Desliza para responder',
      'fr': 'Glisser pour répondre',
    },
    'remind_later': {
      'en': 'Remind Later',
      'ja': 'あとで通知',
      'ko': '나중에 알림',
      'zh': '稍后提醒',
      'es': 'Recordar más tarde',
      'fr': 'Rappeler plus tard',
    },
    'permission_required': {
      'en': 'Permission Required',
      'ja': '権限が必要です',
      'ko': '권한 필요',
      'zh': '需要权限',
      'es': 'Permiso requerido',
      'fr': 'Autorisation requise',
    },
    'microphone_permission': {
      'en': 'Microphone permission is required for voice calls.',
      'ja': '音声通話にはマイクの権限が必要です。',
      'ko': '음성 통話를 위해 마이크 권限이 필요합니다.',
      'zh': '语音通话需要麦克风权限。',
      'es': 'Se requiere permiso de micrófono para llamadas de voz.',
      'fr': 'L\'autorisation du microphone est requise pour les appels vocaux.',
    },
    'camera_permission': {
      'en': 'Camera permission is required for video calls.',
      'ja': 'ビデオ通話にはカメラの権限が必要です。',
      'ko': '영상 통화를 위해 카메라 권한이 필요합니다.',
      'zh': '视频通话需要摄像头权限。',
      'es': 'Se requiere permiso de cámara para videollamadas.',
      'fr': 'L\'autorisation de la caméra est requise pour les appels vidéo.',
    },
    'open_settings': {
      'en': 'Open Settings',
      'ja': '設定を開く',
      'ko': '설정 열기',
      'zh': '打开设置',
      'es': 'Abrir configuración',
      'fr': 'Ouvrir les paramètres',
    },
    'grant_permission': {
      'en': 'Grant Permission',
      'ja': '権限を許可',
      'ko': '권한 허용',
      'zh': '授予权限',
      'es': 'Conceder permiso',
      'fr': 'Accorder l\'autorisation',
    },

    // Calendar & Meeting Notes
    'calendar': {
      'en': 'Calendar',
      'ja': 'カレンダー',
      'ko': '캘린더',
      'zh': '日历',
      'es': 'Calendario',
      'fr': 'Calendrier',
    },
    'meeting_notes': {
      'en': 'Meeting Notes',
      'ja': 'ミーティングノート',
      'ko': '회의 노트',
      'zh': '会议笔记',
      'es': 'Notas de reunión',
      'fr': 'Notes de réunion',
    },
    'call_partner': {
      'en': 'Call Partner',
      'ja': '通話相手',
      'ko': '통화 상대',
      'zh': '通话对象',
      'es': 'Compañero de llamada',
      'fr': 'Partenaire d\'appel',
    },
    'notes': {
      'en': 'Notes',
      'ja': 'メモ',
      'ko': '노트',
      'zh': '笔记',
      'es': 'Notas',
      'fr': 'Notes',
    },
    'ai_summary': {
      'en': 'AI Summary',
      'ja': 'AI要約',
      'ko': 'AI 요약',
      'zh': 'AI摘要',
      'es': 'Resumen de IA',
      'fr': 'Résumé IA',
    },
    'add_calendar_note': {
      'en': 'Add Calendar Note',
      'ja': 'カレンダーメモを追加',
      'ko': '캘린더 메모 추가',
      'zh': '添加日历备忘录',
      'es': 'Agregar nota de calendario',
      'fr': 'Ajouter une note de calendrier',
    },
    'edit_calendar_note': {
      'en': 'Edit Calendar Note',
      'ja': 'カレンダーメモを編集',
      'ko': '캘린더 메모 편집',
      'zh': '编辑日历备忘录',
      'es': 'Editar nota de calendario',
      'fr': 'Modifier la note de calendrier',
    },
    'today_participants': {
      'en': 'Today\'s Participants',
      'ja': '今日の話し相手',
      'ko': '오늘의 대화 상대',
      'zh': '今天的对话者',
      'es': 'Participantes de hoy',
      'fr': 'Participants d\'aujourd\'hui',
    },
    'discussion_points': {
      'en': 'Discussion Points',
      'ja': '話し合いの要点',
      'ko': '논의 요점',
      'zh': '讨论要点',
      'es': 'Puntos de discusión',
      'fr': 'Points de discussion',
    },
    'discussion_results': {
      'en': 'Discussion Results',
      'ja': '話し合いの結果',
      'ko': '논의 결과',
      'zh': '讨论结果',
      'es': 'Resultados de la discusión',
      'fr': 'Résultats de la discussion',
    },
    'import_from_call': {
      'en': 'Import from Call History',
      'ja': '通話履歴からインポート',
      'ko': '통화 기록에서 가져오기',
      'zh': '从通话记录导入',
      'es': 'Importar del historial de llamadas',
      'fr': 'Importer de l\'historique des appels',
    },
    'note_saved': {
      'en': 'Note saved successfully',
      'ja': 'メモを保存しました',
      'ko': '메모가 저장되었습니다',
      'zh': '备忘录已保存',
      'es': 'Nota guardada exitosamente',
      'fr': 'Note enregistrée avec succès',
    },
    'note_deleted': {
      'en': 'Note deleted',
      'ja': 'メモを削除しました',
      'ko': '메모가 삭제되었습니다',
      'zh': '备忘录已删除',
      'es': 'Nota eliminada',
      'fr': 'Note supprimée',
    },
    'imported_from_call': {
      'en': 'Imported from call history',
      'ja': '通話履歴からインポートしました',
      'ko': '통화 기록에서 가져왔습니다',
      'zh': '已从通话记录导入',
      'es': 'Importado del historial de llamadas',
      'fr': 'Importé de l\'historique des appels',
    },

    // Profile Settings
    'profile_settings': {
      'en': 'Profile Settings',
      'ja': 'プロフィール設定',
      'ko': '프로필 설정',
      'zh': '个人资料设置',
      'es': 'Configuración de perfil',
      'fr': 'Paramètres du profil',
    },
    'display_name': {
      'en': 'Display Name',
      'ja': '表示名',
      'ko': '표시 이름',
      'zh': '显示名称',
      'es': 'Nombre para mostrar',
      'fr': 'Nom d\'affichage',
    },
    'sign_out': {
      'en': 'Sign Out',
      'ja': 'サインアウト',
      'ko': '로그아웃',
      'zh': '退出',
      'es': 'Cerrar sesión',
      'fr': 'Se déconnecter',
    },
    'confirm_sign_out': {
      'en': 'Are you sure you want to sign out?',
      'ja': '本当にサインアウトしますか？',
      'ko': '로그아웃하시겠습니까?',
      'zh': '确定要退出吗？',
      'es': '¿Está seguro de que desea cerrar sesión?',
      'fr': 'Êtes-vous sûr de vouloir vous déconnecter ?',
    },

    // Common
    'cancel': {
      'en': 'Cancel',
      'ja': 'キャンセル',
      'ko': '취소',
      'zh': '取消',
      'es': 'Cancelar',
      'fr': 'Annuler',
    },
    'ok': {
      'en': 'OK',
      'ja': 'OK',
      'ko': '확인',
      'zh': '确定',
      'es': 'Aceptar',
      'fr': 'OK',
    },
    'error': {
      'en': 'Error',
      'ja': 'エラー',
      'ko': '오류',
      'zh': '错误',
      'es': 'Error',
      'fr': 'Erreur',
    },
    'success': {
      'en': 'Success',
      'ja': '成功',
      'ko': '성공',
      'zh': '成功',
      'es': 'Éxito',
      'fr': 'Succès',
    },
    'profile_updated': {
      'en': 'Profile updated successfully',
      'ja': 'プロフィールが更新されました',
      'ko': '프로필이 업데이트되었습니다',
      'zh': '个人资料已更新',
      'es': 'Perfil actualizado exitosamente',
      'fr': 'Profil mis à jour avec succès',
    },
    'no_notes_for': {
      'en': 'No notes for',
      'ja': 'メモなし:',
      'ko': '노트 없음:',
      'zh': '无笔记:',
      'es': 'No hay notas para',
      'fr': 'Aucune note pour',
    },
    'add_note_for': {
      'en': 'Add note for',
      'ja': 'メモを追加:',
      'ko': '노트 추加:',
      'zh': '添加笔记:',
      'es': 'Agregar nota para',
      'fr': 'Ajouter une note pour',
    },
    'forgot_password': {
      'en': 'Forgot password?',
      'ja': 'パスワードを忘れましたか？',
      'ko': '비밀번호를 잊으셨나요?',
      'zh': '忘记密码？',
      'es': '¿Olvidaste tu contraseña?',
      'fr': 'Mot de passe oublié?',
    },
    'reset_password': {
      'en': 'Reset Password',
      'ja': 'パスワードをリセット',
      'ko': '비밀번호 재설정',
      'zh': '重置密码',
      'es': 'Restablecer contraseña',
      'fr': 'Réinitialiser le mot de passe',
    },
    'password_reset_sent': {
      'en': 'Password reset email sent',
      'ja': 'パスワードリセットメールを送信しました',
      'ko': '비밀번호 재설정 이메일이 전송되었습니다',
      'zh': '密码重置邮件已发送',
      'es': 'Correo de restablecimiento de contraseña enviado',
      'fr': 'E-mail de réinitialisation du mot de passe envoyé',
    },
    'change_password': {
      'en': 'Change Password',
      'ja': 'パスワード変更',
      'ko': '비밀번호 변경',
      'zh': '更改密码',
      'es': 'Cambiar contraseña',
      'fr': 'Changer le mot de passe',
    },
    'current_password': {
      'en': 'Current Password',
      'ja': '現在のパスワード',
      'ko': '현재 비밀번호',
      'zh': '当前密码',
      'es': 'Contraseña actual',
      'fr': 'Mot de passe actuel',
    },
    'new_password': {
      'en': 'New Password',
      'ja': '新しいパスワード',
      'ko': '새 비밀번호',
      'zh': '新密码',
      'es': 'Nueva contraseña',
      'fr': 'Nouveau mot de passe',
    },
    'confirm_password': {
      'en': 'Confirm Password',
      'ja': 'パスワード確認',
      'ko': '비밀번호 확인',
      'zh': '确认密码',
      'es': 'Confirmar contraseña',
      'fr': 'Confirmer le mot de passe',
    },
    'passwords_not_match': {
      'en': 'Passwords do not match',
      'ja': 'パスワードが一致しません',
      'ko': '비밀번호가 일치하지 않습니다',
      'zh': '密码不匹配',
      'es': 'Las contraseñas no coinciden',
      'fr': 'Les mots de passe ne correspondent pas',
    },
    'password_changed': {
      'en': 'Password changed successfully',
      'ja': 'パスワードが変更されました',
      'ko': '비밀번호가 변경되었습니다',
      'zh': '密码已更改',
      'es': 'Contraseña cambiada exitosamente',
      'fr': 'Mot de passe changé avec succès',
    },

    // Reorder Friends
    'reorder_friends': {
      'en': 'Reorder Friends',
      'ja': '友達の並び替え',
      'ko': '친구 순서 변경',
      'zh': '重新排列好友',
      'es': 'Reordenar amigos',
      'fr': 'Réorganiser les amis',
    },
    'reorder_instruction': {
      'en': 'Long press and drag to change order',
      'ja': '長押ししてドラッグで順序を変更できます',
      'ko': '길게 눌러 드래그하여 순서를 변경하세요',
      'zh': '长按并拖动以更改顺序',
      'es': 'Mantén presionado y arrastra para cambiar el orden',
      'fr': 'Appuyez longuement et faites glisser pour changer l\'ordre',
    },
    'save_changes': {
      'en': 'Save Changes',
      'ja': '変更を保存',
      'ko': '변경사항 저장',
      'zh': '保存更改',
      'es': 'Guardar cambios',
      'fr': 'Enregistrer les modifications',
    },
    'friend_order_saved': {
      'en': 'Friend order saved successfully',
      'ja': '友達の並び順を保存しました',
      'ko': '친구 순서가 저장되었습니다',
      'zh': '好友顺序已保存',
      'es': 'Orden de amigos guardado exitosamente',
      'fr': 'Ordre des amis enregistré avec succès',
    },
    'discard_changes': {
      'en': 'Discard Changes?',
      'ja': '変更を破棄しますか？',
      'ko': '변경사항을 취소하시겠습니까?',
      'zh': '放弃更改？',
      'es': '¿Descartar cambios?',
      'fr': 'Abandonner les modifications?',
    },
    'unsaved_changes_message': {
      'en': 'You have unsaved changes. Do you want to discard them?',
      'ja': '保存されていない変更があります。破棄しますか？',
      'ko': '저장되지 않은 변경사항이 있습니다. 취소하시겠습니까?',
      'zh': '您有未保存的更改。要放弃它们吗？',
      'es': 'Tienes cambios sin guardar. ¿Quieres descartarlos?',
      'fr': 'Vous avez des modifications non enregistrées. Voulez-vous les abandonner?',
    },
    'discard': {
      'en': 'Discard',
      'ja': '破棄',
      'ko': '취소',
      'zh': '放弃',
      'es': 'Descartar',
      'fr': 'Abandonner',
    },

    // Theme Settings
    'theme': {
      'en': 'Theme',
      'ja': 'テーマ',
      'ko': '테마',
      'zh': '主题',
      'es': 'Tema',
      'fr': 'Thème',
    },
    'light_mode': {
      'en': 'Light Mode',
      'ja': 'ライトモード',
      'ko': '라이트 모드',
      'zh': '浅色模式',
      'es': 'Modo claro',
      'fr': 'Mode clair',
    },
    'dark_mode': {
      'en': 'Dark Mode',
      'ja': 'ダークモード',
      'ko': '다크 모드',
      'zh': '深色模式',
      'es': 'Modo oscuro',
      'fr': 'Mode sombre',
    },
    'auto_mode': {
      'en': 'Auto (System)',
      'ja': '自動（システム）',
      'ko': '자동 (시스템)',
      'zh': '自动（系统）',
      'es': 'Automático (Sistema)',
      'fr': 'Automatique (Système)',
    },

    // Delete Friend Dialog
    'delete_friend': {
      'en': 'Delete Friend',
      'ja': '友達を削除',
      'ko': '친구 삭제',
      'zh': '删除好友',
      'es': 'Eliminar amigo',
      'fr': 'Supprimer un ami',
    },
    'delete_friend_confirmation': {
      'en': 'By deleting this friend, all data (chat history) will be lost. Are you sure you want to continue?',
      'ja': '友達を削除することにより、データ（チャット履歴）が失われますが、それでも良いですか？',
      'ko': '친구를 삭제하면 데이터(채팅 기록)가 손실됩니다. 계속하시겠습니까?',
      'zh': '删除好友后，所有数据（聊天记录）将会丢失。您确定要继续吗？',
      'es': 'Al eliminar este amigo, se perderán todos los datos (historial de chat). ¿Está seguro de que desea continuar?',
      'fr': 'En supprimant cet ami, toutes les données (historique de chat) seront perdues. Êtes-vous sûr de vouloir continuer?',
    },
    'yes': {
      'en': 'Yes',
      'ja': 'はい',
      'ko': '예',
      'zh': '是',
      'es': 'Sí',
      'fr': 'Oui',
    },
    'no': {
      'en': 'No',
      'ja': 'いいえ',
      'ko': '아니오',
      'zh': '否',
      'es': 'No',
      'fr': 'Non',
    },

    // Message Read Status
    'read': {
      'en': 'Read',
      'ja': '既読',
      'ko': '읽음',
      'zh': '已读',
      'es': 'Leído',
      'fr': 'Lu',
    },
    'unread': {
      'en': 'Unread',
      'ja': '未読',
      'ko': '읽지 않음',
      'zh': '未读',
      'es': 'No leído',
      'fr': 'Non lu',
    },

    // Settings
    'settings': {
      'en': 'Settings',
      'ja': '設定',
      'ko': '설정',
      'zh': '设置',
      'es': 'Configuración',
      'fr': 'Paramètres',
    },
    'settings_coming_soon': {
      'en': 'Settings coming soon',
      'ja': '設定は近日公開予定',
      'ko': '설정 곧 출시 예정',
      'zh': '设置即将推出',
      'es': 'Configuración próximamente',
      'fr': 'Paramètres à venir',
    },

    // Chat Settings
    'chat_settings': {
      'en': 'Chat Settings',
      'ja': 'チャット設定',
      'ko': '채팅 설정',
      'zh': '聊天设置',
      'es': 'Configuración de chat',
      'fr': 'Paramètres de chat',
    },
    
    // Chat Background Settings
    'chat_background': {
      'en': 'Chat Background',
      'ja': 'チャット背景',
      'ko': '채팅 배경',
      'zh': '聊天背景',
      'es': 'Fondo de chat',
      'fr': 'Arrière-plan du chat',
    },
    'select_chat_background': {
      'en': 'Select Chat Background',
      'ja': 'チャット背景を選択',
      'ko': '채팅 배경 선택',
      'zh': '选择聊天背景',
      'es': 'Seleccionar fondo de chat',
      'fr': 'Sélectionner l\'arrière-plan du chat',
    },
    'background_description': {
      'en': 'Choose a background style for your chat conversations',
      'ja': 'チャット会話の背景スタイルを選択',
      'ko': '채팅 대화의 배경 스타일을 선택하세요',
      'zh': '为您的聊天对话选择背景样式',
      'es': 'Elige un estilo de fondo para tus conversaciones de chat',
      'fr': 'Choisissez un style d\'arrière-plan pour vos conversations de chat',
    },
    'background_saved': {
      'en': 'Background saved successfully!',
      'ja': '背景を保存しました！',
      'ko': '배경이 저장되었습니다!',
      'zh': '背景保存成功！',
      'es': '¡Fondo guardado exitosamente!',
      'fr': 'Arrière-plan enregistré avec succès!',
    },

    // Background Options
    'bg_default': {
      'en': 'Default',
      'ja': 'デフォルト',
      'ko': '기본',
      'zh': '默认',
      'es': 'Predeterminado',
      'fr': 'Par défaut',
    },
    'bg_blue_gradient': {
      'en': 'Blue Gradient',
      'ja': '青のグラデーション',
      'ko': '블루 그라데이션',
      'zh': '蓝色渐变',
      'es': 'Gradiente azul',
      'fr': 'Dégradé bleu',
    },
    'bg_purple_gradient': {
      'en': 'Purple Gradient',
      'ja': '紫のグラデーション',
      'ko': '퍼플 그라데이션',
      'zh': '紫色渐变',
      'es': 'Gradiente morado',
      'fr': 'Dégradé violet',
    },
    'bg_pink_gradient': {
      'en': 'Pink Gradient',
      'ja': 'ピンクのグラデーション',
      'ko': '핑크 그라데이션',
      'zh': '粉色渐变',
      'es': 'Gradiente rosa',
      'fr': 'Dégradé rose',
    },
    'bg_green_gradient': {
      'en': 'Green Gradient',
      'ja': '緑のグラデーション',
      'ko': '그린 그라데이션',
      'zh': '绿色渐变',
      'es': 'Gradiente verde',
      'fr': 'Dégradé vert',
    },
    'bg_orange_gradient': {
      'en': 'Orange Gradient',
      'ja': 'オレンジのグラデーション',
      'ko': '오렌지 그라데이션',
      'zh': '橙色渐变',
      'es': 'Gradiente naranja',
      'fr': 'Dégradé orange',
    },
    'bg_dark_blue': {
      'en': 'Dark Blue',
      'ja': 'ダークブルー',
      'ko': '다크 블루',
      'zh': '深蓝色',
      'es': 'Azul oscuro',
      'fr': 'Bleu foncé',
    },
    'bg_dark_purple': {
      'en': 'Dark Purple',
      'ja': 'ダークパープル',
      'ko': '다크 퍼플',
      'zh': '深紫色',
      'es': 'Morado oscuro',
      'fr': 'Violet foncé',
    },
    'bg_sunset': {
      'en': 'Sunset',
      'ja': '夕焼け',
      'ko': '석양',
      'zh': '日落',
      'es': 'Atardecer',
      'fr': 'Coucher de soleil',
    },
    'bg_ocean': {
      'en': 'Ocean',
      'ja': '海',
      'ko': '바다',
      'zh': '海洋',
      'es': 'Océano',
      'fr': 'Océan',
    },

    // Recording & Transcription
    'recording_saved': {
      'en': 'Recording saved',
      'ja': '録音を保存しました',
      'ko': '녹음이 저장되었습니다',
      'zh': '录音已保存',
      'es': 'Grabación guardada',
      'fr': 'Enregistrement sauvegardé',
    },
    'recording_save_failed': {
      'en': 'Failed to save recording',
      'ja': '録音の保存に失敗しました',
      'ko': '녹음 저장에 실패했습니다',
      'zh': '保存录音失败',
      'es': 'Error al guardar la grabación',
      'fr': 'Échec de la sauvegarde de l\'enregistrement',
    },
    'transcribe': {
      'en': 'Transcribe',
      'ja': '文字起こし',
      'ko': '텍스트 변환',
      'zh': '转录',
      'es': 'Transcribir',
      'fr': 'Transcrire',
    },
    'transcribing_with_ai': {
      'en': 'Transcribing...',
      'ja': '文字起こし中...',
      'ko': '텍스트 변환 중...',
      'zh': '转录中...',
      'es': 'Transcribiendo...',
      'fr': 'Transcription...',
    },
    'transcription_completed': {
      'en': 'Transcription completed',
      'ja': '文字起こしが完了しました',
      'ko': '텍스트 변환이 완료되었습니다',
      'zh': '转录完成',
      'es': 'Transcripción completada',
      'fr': 'Transcription terminée',
    },
    'transcription_failed': {
      'en': 'Transcription failed',
      'ja': '文字起こしに失敗しました',
      'ko': '텍스트 변환에 실패했습니다',
      'zh': '转录失败',
      'es': 'Error en la transcripción',
      'fr': 'Échec de la transcription',
    },
    'transcription_error': {
      'en': 'Transcription error',
      'ja': '文字起こしエラー',
      'ko': '텍스트 변환 오류',
      'zh': '转录错误',
      'es': 'Error de transcripción',
      'fr': 'Erreur de transcription',
    },
    'transcription_result': {
      'en': 'Transcription Result',
      'ja': '文字起こし結果',
      'ko': '텍스트 변환 결과',
      'zh': '转录结果',
      'es': 'Resultado de transcripción',
      'fr': 'Résultat de transcription',
    },
    'confirm_button': {
      'en': 'Confirm',
      'ja': '確認',
      'ko': '확인',
      'zh': '确认',
      'es': 'Confirmar',
      'fr': 'Confirmer',
    },
    'close': {
      'en': 'Close',
      'ja': '閉じる',
      'ko': '닫기',
      'zh': '关闭',
      'es': 'Cerrar',
      'fr': 'Fermer',
    },
    'call_history': {
      'en': 'Call History',
      'ja': '通話履歴',
      'ko': '통화 기록',
      'zh': '通话记录',
      'es': 'Historial de llamadas',
      'fr': 'Historique des appels',
    },
    'reload': {
      'en': 'Reload',
      'ja': '再読み込み',
      'ko': '새로고침',
      'zh': '重新加载',
      'es': 'Recargar',
      'fr': 'Recharger',
    },
    'no_call_history': {
      'en': 'No call history',
      'ja': '通話履歴がありません',
      'ko': '통화 기록이 없습니다',
      'zh': '无通话记录',
      'es': 'Sin historial de llamadas',
      'fr': 'Aucun historique d\'appels',
    },
    'call_duration': {
      'en': 'Duration',
      'ja': '通話時間',
      'ko': '통화 시간',
      'zh': '通话时长',
      'es': 'Duración',
      'fr': 'Durée',
    },
    'transcription_processing': {
      'en': 'Transcribing...',
      'ja': '文字起こし中...',
      'ko': '음성 인식 중...',
      'zh': '转录中...',
      'es': 'Transcribiendo...',
      'fr': 'Transcription en cours...',
    },
    'processing_message': {
      'en': 'Processing...',
      'ja': '処理中...',
      'ko': '처리 중...',
      'zh': '处理中...',
      'es': 'Procesando...',
      'fr': 'Traitement...',
    },
    'auto_display_message': {
      'en': 'Will display automatically when completed',
      'ja': '完了すると自動的に表示されます',
      'ko': '완료되면 자동으로 표시됩니다',
      'zh': '完成后将自动显示',
      'es': 'Se mostrará automáticamente al completar',
      'fr': 'S\'affichera automatiquement une fois terminé',
    },
    'no_transcription_data': {
      'en': 'No transcription data',
      'ja': '文字起こしデータがありません',
      'ko': '음성 인식 데이터 없음',
      'zh': '无转录数据',
      'es': 'Sin datos de transcripción',
      'fr': 'Aucune donnée de transcription',
    },
    'copy_instruction': {
      'en': 'You can select and copy the text',
      'ja': 'テキストを選択してコピーできます',
      'ko': '텍스트를 선택하고 복사할 수 있습니다',
      'zh': '您可以选择并复制文本',
      'es': 'Puede seleccionar y copiar el texto',
      'fr': 'Vous pouvez sélectionner et copier le texte',
    },
    'unknown_contact': {
      'en': 'Unknown',
      'ja': '不明',
      'ko': '알 수 없음',
      'zh': '未知',
      'es': 'Desconocido',
      'fr': 'Inconnu',
    },
    'retry': {
      'en': 'Retry',
      'ja': '再試行',
      'ko': '재시도',
      'zh': '重试',
      'es': 'Reintentar',
      'fr': 'Réessayer',
    },
    'edit': {
      'en': 'Edit',
      'ja': '編集',
      'ko': '편집',
      'zh': '编辑',
      'es': 'Editar',
      'fr': 'Modifier',
    },
    'edit_transcription': {
      'en': 'Edit Transcription',
      'ja': '文字起こしを編集',
      'ko': '음성 인식 편집',
      'zh': '编辑转录',
      'es': 'Editar transcripción',
      'fr': 'Modifier la transcription',
    },
    'enter_text': {
      'en': 'Enter text',
      'ja': 'テキストを入力',
      'ko': '텍스트 입력',
      'zh': '输入文本',
      'es': 'Ingrese texto',
      'fr': 'Entrez le texte',
    },
    'cancel': {
      'en': 'Cancel',
      'ja': 'キャンセル',
      'ko': '취소',
      'zh': '取消',
      'es': 'Cancelar',
      'fr': 'Annuler',
    },
    'save': {
      'en': 'Save',
      'ja': '保存',
      'ko': '저장',
      'zh': '保存',
      'es': 'Guardar',
      'fr': 'Enregistrer',
    },
    'transcription_updated': {
      'en': 'Transcription updated',
      'ja': '文字起こしを更新しました',
      'ko': '음성 인식이 업데이트되었습니다',
      'zh': '转录已更新',
      'es': 'Transcripción actualizada',
      'fr': 'Transcription mise à jour',
    },
    'ai_summary': {
      'en': 'AI Summary',
      'ja': 'AI要約',
      'ko': 'AI 요약',
      'zh': 'AI摘要',
      'es': 'Resumen de IA',
      'fr': 'Résumé IA',
    },
    'no_transcription_to_summarize': {
      'en': 'No transcription to summarize',
      'ja': '要約する文字起こしがありません',
      'ko': '요약할 음성 인식이 없습니다',
      'zh': '没有可摘要的转录',
      'es': 'Sin transcripción para resumir',
      'fr': 'Aucune transcription à résumer',
    },
    'summary_failed': {
      'en': 'Failed to generate summary',
      'ja': '要約の生成に失敗しました',
      'ko': '요약 생成 실패',
      'zh': '生成摘要失败',
      'es': 'Error al generar resumen',
      'fr': 'Échec de la génération du résumé',
    },
    'replace_with_summary': {
      'en': 'Replace with Summary',
      'ja': '要約で置き換える',
      'ko': '요약으로 바꾸기',
      'zh': '替换为摘要',
      'es': 'Reemplazar con resumen',
      'fr': 'Remplacer par le résumé',
    },
    'replace_transcription_hint': {
      'en': 'Replace the original transcription with this summary?',
      'ja': '元の文字起こしをこの要約で置き換えますか？',
      'ko': '원본 녹취록을 이 요약으로 바꾸시겠습니까?',
      'zh': '是否将原始转录替换为此摘要？',
      'es': '¿Reemplazar la transcripción original con este resumen?',
      'fr': 'Remplacer la transcription originale par ce résumé ?',
    },
    'transcription_replaced': {
      'en': 'Transcription replaced with summary',
      'ja': '文字起こしを要約で置き換えました',
      'ko': '녹취록이 요약으로 바뀌었습니다',
      'zh': '转录已替换为摘要',
      'es': 'Transcripción reemplazada con resumen',
      'fr': 'Transcription remplacée par le résumé',
    },
    'error': {
      'en': 'Error',
      'ja': 'エラー',
      'ko': '오류',
      'zh': '错误',
      'es': 'Error',
      'fr': 'Erreur',
    },

    // Calendar Memo System
    'no_calls_on_this_day': {
      'en': 'No calls on this day',
      'ja': 'この日は通話がありません',
      'ko': '이 날은 통화가 없습니다',
      'zh': '这一天没有通话',
      'es': 'No hay llamadas en este día',
      'fr': 'Aucun appel ce jour',
    },
    'create_new_memo': {
      'en': 'Create New Memo',
      'ja': '新しいメモ',
      'ko': '새 메모',
      'zh': '新备忘录',
      'es': 'Nuevo memo',
      'fr': 'Nouveau mémo',
    },
    'edit_memo': {
      'en': 'Edit Memo',
      'ja': 'メモを編集',
      'ko': '메모 편집',
      'zh': '编辑备忘录',
      'es': 'Editar memo',
      'fr': 'Modifier le mémo',
    },
    'contact_of_the_day': {
      'en': 'Contact of the Day',
      'ja': '今日の話し相手',
      'ko': '오늘의 통화 상대',
      'zh': '今日联系人',
      'es': 'Contacto del día',
      'fr': 'Contact du jour',
    },
    'key_points': {
      'en': 'Key Points',
      'ja': '話し合いの要点',
      'ko': '논의 요점',
      'zh': '讨论要点',
      'es': 'Puntos clave',
      'fr': 'Points clés',
    },
    'discussion_results': {
      'en': 'Discussion Results',
      'ja': '話し合いの結果',
      'ko': '논의 결과',
      'zh': '讨论结果',
      'es': 'Resultados de la discusión',
      'fr': 'Résultats de la discussion',
    },
    'key_points_short': {
      'en': '📝 Key Points:',
      'ja': '📝 要点:',
      'ko': '📝 요점:',
      'zh': '📝 要点:',
      'es': '📝 Puntos clave:',
      'fr': '📝 Points clés:',
    },
    'results_short': {
      'en': '✅ Results:',
      'ja': '✅ 結果:',
      'ko': '✅ 결과:',
      'zh': '✅ 结果:',
      'es': '✅ Resultados:',
      'fr': '✅ Résultats:',
    },
    'key_points_hint': {
      'en': 'Enter the topics discussed in the call',
      'ja': '通話で話し合った内容を入力してください',
      'ko': '통화에서 논의한 내용을 입력하세요',
      'zh': '输入通话中讨论的内容',
      'es': 'Ingrese los temas discutidos en la llamada',
      'fr': 'Entrez les sujets discutés lors de l\'appel',
    },
    'results_hint': {
      'en': 'Enter conclusions or next actions',
      'ja': '結論や次のアクションを入力してください',
      'ko': '결론이나 다음 행동을 입력하세요',
      'zh': '输入结论或下一步行动',
      'es': 'Ingrese conclusiones o próximas acciones',
      'fr': 'Entrez les conclusions ou les prochaines actions',
    },
    'note_color': {
      'en': 'Note Color',
      'ja': 'ノートの色',
      'ko': '메모 색상',
      'zh': '笔记颜色',
      'es': 'Color de nota',
      'fr': 'Couleur de note',
    },
    'save_memo': {
      'en': 'Save Memo',
      'ja': 'メモを保存',
      'ko': '메모 저장',
      'zh': '保存备忘录',
      'es': 'Guardar memo',
      'fr': 'Enregistrer le mémo',
    },
    'saving': {
      'en': 'Saving...',
      'ja': '保存中...',
      'ko': '저장 중...',
      'zh': '保存中...',
      'es': 'Guardando...',
      'fr': 'Enregistrement...',
    },
    'import_from_call_history': {
      'en': 'Import from Call History',
      'ja': '通話履歴から要点をインポート',
      'ko': '통화 기록에서 가져오기',
      'zh': '从通话记录导入',
      'es': 'Importar del historial de llamadas',
      'fr': 'Importer de l\'historique d\'appels',
    },
    'imported_from_call': {
      'en': 'Imported from call history',
      'ja': '通話履歴から要点をインポートしました',
      'ko': '통화 기록에서 가져왔습니다',
      'zh': '已从通话记录导入',
      'es': 'Importado del historial de llamadas',
      'fr': 'Importé de l\'historique d\'appels',
    },
    'memo_saved': {
      'en': 'Memo saved',
      'ja': 'メモを保存しました',
      'ko': '메모가 저장되었습니다',
      'zh': '备忘录已保存',
      'es': 'Memo guardado',
      'fr': 'Mémo enregistré',
    },
    'no_memos_yet': {
      'en': 'No memos yet',
      'ja': 'まだメモがありません',
      'ko': '아직 메모가 없습니다',
      'zh': '还没有备忘录',
      'es': 'Aún no hay memos',
      'fr': 'Aucun mémo pour le moment',
    },
    'tap_plus_to_create': {
      'en': 'Tap + button to create memo',
      'ja': '下の + ボタンでメモを作成',
      'ko': '+ 버튼을 눌러 메모 생성',
      'zh': '点击+按钮创建备忘录',
      'es': 'Toca el botón + para crear memo',
      'fr': 'Appuyez sur + pour créer un mémo',
    },
    'delete_memo': {
      'en': 'Delete Memo',
      'ja': 'メモを削除',
      'ko': '메모 삭제',
      'zh': '删除备忘录',
      'es': 'Eliminar memo',
      'fr': 'Supprimer le mémo',
    },
    'delete_memo_confirm': {
      'en': 'Are you sure you want to delete this memo?',
      'ja': 'このメモを削除してもよろしいですか？',
      'ko': '이 메모를 삭제하시겠습니까?',
      'zh': '确定要删除此备忘录吗？',
      'es': '¿Estás seguro de que deseas eliminar este memo?',
      'fr': 'Êtes-vous sûr de vouloir supprimer ce mémo ?',
    },
    'memo_deleted': {
      'en': 'Memo deleted',
      'ja': 'メモを削除しました',
      'ko': '메모가 삭제되었습니다',
      'zh': '备忘录已删除',
      'es': 'Memo eliminado',
      'fr': 'Mémo supprimé',
    },
    'delete': {
      'en': 'Delete',
      'ja': '削除',
      'ko': '삭제',
      'zh': '删除',
      'es': 'Eliminar',
      'fr': 'Supprimer',
    },
    'call_singular': {
      'en': 'call',
      'ja': '回の通話',
      'ko': '통화',
      'zh': '次通话',
      'es': 'llamada',
      'fr': 'appel',
    },
    'calls_plural': {
      'en': 'calls',
      'ja': '回の通話',
      'ko': '통화',
      'zh': '次通话',
      'es': 'llamadas',
      'fr': 'appels',
    },
    'please_enter_key_points': {
      'en': 'Please enter key points',
      'ja': '話し合いの要点を入力してください',
      'ko': '요점을 입력하세요',
      'zh': '请输入要点',
      'es': 'Por favor ingrese los puntos clave',
      'fr': 'Veuillez entrer les points clés',
    },
    'please_enter_results': {
      'en': 'Please enter discussion results',
      'ja': '話し合いの結果を入力してください',
      'ko': '결과를 입력하세요',
      'zh': '请输入结果',
      'es': 'Por favor ingrese los resultados',
      'fr': 'Veuillez entrer les résultats',
    },
    'imported': {
      'en': 'Imported',
      'ja': 'インポート',
      'ko': '가져옴',
      'zh': '已导入',
      'es': 'Importado',
      'fr': 'Importé',
    },
    'calls': {
      'en': 'calls',
      'ja': '件の通話',
      'ko': '통화',
      'zh': '通话',
      'es': 'llamadas',
      'fr': 'appels',
    },
    'call': {
      'en': 'call',
      'ja': '件の通話',
      'ko': '통화',
      'zh': '通话',
      'es': 'llamada',
      'fr': 'appel',
    },

  };
}
