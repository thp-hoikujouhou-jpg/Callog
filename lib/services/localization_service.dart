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

  // Load language from Firestore with caching
  Future<void> loadLanguageFromFirestore() async {
    // Prevent duplicate loading
    if (_isLoading) return;
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Skip if already loaded for this user
        if (_cachedUserId == user.uid) return;
        
        _isLoading = true;
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final language = doc.data()?['language'] as String?;
          if (language != null && supportedLanguages.containsKey(language)) {
            _currentLanguage = language;
            _cachedUserId = user.uid;
            notifyListeners(); // Notify all listeners when language is loaded
          }
        }
      }
    } catch (e) {
      // If error, keep default language
      if (kDebugMode) {
        debugPrint('Error loading language: $e');
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
  };
}
