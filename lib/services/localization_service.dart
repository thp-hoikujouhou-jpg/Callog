class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  String _currentLanguage = 'en';
  
  String get currentLanguage => _currentLanguage;

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

  void setLanguage(String languageCode) {
    if (supportedLanguages.containsKey(languageCode)) {
      _currentLanguage = languageCode;
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
  };
}
