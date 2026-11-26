import 'package:flutter/material.dart';

/// Holds the selected French or Arabic application language.
class LangController extends ChangeNotifier {
  String _lang = 'fr';

  String get lang => _lang;
  bool get isAr => _lang == 'ar';

  void set(String language) {
    if (language == _lang) return;
    _lang = language;
    notifyListeners();
  }
}

class LangScope extends InheritedNotifier<LangController> {
  const LangScope({
    super.key,
    required LangController controller,
    required super.child,
  }) : super(notifier: controller);

  static LangController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LangScope>()!.notifier!;
}

extension Tr on BuildContext {
  String tr(String key) => _strings[key]?[LangScope.of(this).lang] ?? key;
  bool get isAr => LangScope.of(this).isAr;
  LangController get lang => LangScope.of(this);
}

const _strings = <String, Map<String, String>>{
  'api_load_error': {
    'fr':
        "Impossible de charger les données. Vérifiez la connexion et réessayez.",
    'ar': "تعذّر تحميل البيانات. تثبّت من الاتصال وعاود.",
  },
  'api_error_401': {
    'fr':
        "Session expirée. Demandez une nouvelle invitation à votre administrateur.",
    'ar': "انتهت الجلسة. اطلب دعوة جديدة من المسؤول.",
  },
  'api_error_402': {
    'fr': "L'abonnement de votre administrateur a expiré.",
    'ar': "انتهى اشتراك المسؤول.",
  },
  'api_error_403': {
    'fr': "Vous n'êtes pas autorisé à effectuer cette action.",
    'ar': "ليس لديك إذن لتنفيذ هذا الإجراء.",
  },
  'api_error_404': {
    'fr': "La ressource demandée est introuvable.",
    'ar': "المورد المطلوب غير موجود.",
  },
  'api_error_422': {
    'fr': "Les informations fournies ne sont pas valides.",
    'ar': "المعلومات المقدمة غير صالحة.",
  },
  'api_error_409': {
    'fr': "Cet identifiant de bovin ou cette boucle existe déjà.",
    'ar': "معرّف هذه البقرة أو هذه العلامة موجود بالفعل.",
  },
  'add_cow': {'fr': "Ajouter un bovin", 'ar': "إضافة بقرة"},
  'cow_id': {'fr': "Identifiant du bovin", 'ar': "معرّف البقرة"},
  'nfc_tag_uid': {'fr': "UID de la boucle NFC", 'ar': "معرّف حلقة NFC"},
  'birth_date': {'fr': "Date de naissance", 'ar': "تاريخ الميلاد"},
  'select_birth_date': {
    'fr': "Choisir la date de naissance",
    'ar': "اختر تاريخ الميلاد",
  },
  'birth_date_required': {
    'fr': "Veuillez choisir une date de naissance passée ou présente.",
    'ar': "يرجى اختيار تاريخ ميلاد في الماضي أو اليوم.",
  },
  'weight_kg': {'fr': "Poids (kg)", 'ar': "الوزن (كغ)"},
  'weight_invalid': {
    'fr': "Le poids doit être supérieur à 0 et ne pas dépasser 1 500 kg.",
    'ar': "يجب أن يكون الوزن أكبر من 0 وألا يتجاوز 1500 كغ.",
  },
  'cow_id_required': {
    'fr': "Veuillez saisir un identifiant.",
    'ar': "يرجى إدخال معرّف.",
  },
  'cow_type': {'fr': "Type", 'ar': "النوع"},
  'select_cow_type': {'fr': "Choisir un type", 'ar': "اختر النوع"},
  'cow_type_dairy': {'fr': "Laitier", 'ar': "حلّاب"},
  'cow_type_beef': {'fr': "Viande", 'ar': "لحم"},
  'cow_type_dual': {'fr': "Mixte", 'ar': "مزدوج"},
  'breed': {'fr': "Race", 'ar': "السلالة"},
  'select_breed': {'fr': "Choisir une race", 'ar': "اختر السلالة"},
  'create_cow': {'fr': "Enregistrer le bovin", 'ar': "تسجيل البقرة"},
  'api_error_429': {
    'fr': "Trop de tentatives. Veuillez réessayer dans une minute.",
    'ar': "محاولات كثيرة. يرجى المحاولة مجددًا بعد دقيقة.",
  },
  'api_error_network': {
    'fr': "Impossible de contacter le serveur. Vérifiez votre connexion.",
    'ar': "تعذّر الاتصال بالخادم. تحقق من اتصالك.",
  },
  'api_error_generic': {
    'fr': "Une erreur est survenue. Réessayez.",
    'ar': "حدث خطأ. حاول مجددًا.",
  },
  'appetite_data_unavailable': {
    'fr': "Les données d’appétit ne sont pas disponibles pour le moment.",
    'ar': "بيانات الشهية غير متاحة حاليًا.",
  },
  'retry': {'fr': "Réessayer", 'ar': "عاود"},
  'try_again': {'fr': "Réessayer", 'ar': "حاول مرة أخرى"},
  'server_waking_up': {
    'fr': "Le serveur se réveille. Merci de patienter…",
    'ar': "الخادم قيد التشغيل. يرجى الانتظار…",
  },
  'session_expired_message': {
    'fr':
        "Session expirée. Demandez une nouvelle invitation à votre administrateur.",
    'ar': "انتهت الجلسة. اطلب دعوة جديدة من المسؤول.",
  },
  'subscription_expired_message': {
    'fr':
        "L'abonnement de votre administrateur a expiré. Veuillez contacter votre administrateur.",
    'ar': "انتهى اشتراك المسؤول. يرجى الاتصال بالمسؤول.",
  },
  'logout': {'fr': "Déconnexion", 'ar': "تسجيل الخروج"},
  'logout_confirmation': {
    'fr':
        "Vous aurez besoin d'une nouvelle invitation de votre administrateur pour revenir.",
    'ar': "ستحتاج إلى دعوة جديدة من المسؤول للعودة.",
  },
  'no_cows': {
    'fr': "Aucune donnée d'élevage disponible.",
    'ar': "ما فماش بيانات متاحة على القطيع.",
  },
  'empty_search': {
    'fr': "Aucun identifiant ne correspond à la recherche.",
    'ar': "ما فماش رقم يوافق البحث.",
  },
  'dashboard_title': {'fr': "Mangeoire intelligente", 'ar': "المعلفة الذكية"},
  'hello': {'fr': "Bonjour", 'ar': "مرحبًا"},
  'appetite_increasing': {'fr': "En hausse", 'ar': "في ارتفاع"},
  'appetite_stable': {'fr': "Stable", 'ar': "مستقر"},
  'appetite_decreasing': {'fr': "En baisse", 'ar': "في انخفاض"},
  'appetite_no_data': {
    'fr': "Aucune donnée d’appétit",
    'ar': "لا توجد بيانات للشهية",
  },
  'appetite_increasing_description': {
    'fr': "L’appétit de ces animaux est en hausse.",
    'ar': "شهية هذه الحيوانات في ارتفاع.",
  },
  'appetite_stable_description': {
    'fr': "L’appétit de ces animaux est stable.",
    'ar': "شهية هذه الحيوانات مستقرة.",
  },
  'appetite_decreasing_description': {
    'fr': "L’appétit de ces animaux est en baisse.",
    'ar': "شهية هذه الحيوانات في انخفاض.",
  },
  'appetite_no_data_description': {
    'fr': "Aucune classe d’appétit n’est disponible pour ces animaux.",
    'ar': "لا تتوفر بيانات شهية لهذه الحيوانات.",
  },
  'appetite_class_empty': {
    'fr': "Aucun animal dans cette catégorie.",
    'ar': "لا توجد حيوانات في هذه الفئة.",
  },
  'last_update': {
    'fr': "Dernière mise à jour : {time}",
    'ar': "آخر تحديث: {time}",
  },
  'tracked_cows': {'fr': "Animaux suivis", 'ar': "الحيوانات المتابعة"},
  'open_cows': {'fr': "Voir les animaux", 'ar': "شوف الحيوانات"},
  'my_cows': {'fr': "Mes animaux", 'ar': "الحيوانات متاعي"},
  'search_hint': {'fr': "Chercher un identifiant", 'ar': "لوّج على رقم"},
  'quick_nfc': {'fr': "Scanner une boucle", 'ar': "اسكاني بطاقة"},
  'telemetry_title': {'fr': "Dernières données", 'ar': "آخر البيانات"},
  'telemetry_date': {'fr': "Date", 'ar': "التاريخ"},
  'telemetry_age': {'fr': "Âge (mois)", 'ar': "العمر (شهر)"},
  'food_consumed': {'fr': "Aliment consommé (g)", 'ar': "العلف المستهلك (غ)"},
  'feed_offered': {'fr': "Aliment distribué (g)", 'ar': "العلف المقدم (غ)"},
  'visits': {'fr': "Visites", 'ar': "الزيارات"},
  'eating_minutes': {
    'fr': "Temps d'alimentation (min)",
    'ar': "مدة الأكل (دق)",
  },
  'meal_duration': {
    'fr': "Durée moyenne d'un repas (min)",
    'ar': "متوسط مدة الوجبة (دق)",
  },
  'no_food_visits': {
    'fr': "Visites sans alimentation",
    'ar': "زيارات دون أكل",
  },
  'first_visit': {'fr': "Première visite (h)", 'ar': "أول زيارة (س)"},
  'last_visit': {'fr': "Dernière visite (h)", 'ar': "آخر زيارة (س)"},
  'day_over': {'fr': "Journée terminée", 'ar': "انتهى اليوم"},
  'yes': {'fr': "Oui", 'ar': "نعم"},
  'no': {'fr': "Non", 'ar': "لا"},
  'feature_unavailable': {
    'fr': "Cette fonction n'est pas encore disponible côté serveur.",
    'ar': "الميزة هاذي مازالت موش متوفرة في الخادم.",
  },
  'biometric_unavailable': {
    'fr':
        "L'authentification biométrique n'est pas configurée dans cette version.",
    'ar': "المصادقة بالبصمة موش مهيّأة في النسخة هاذي.",
  },
  'route_unavailable': {
    'fr': "Écran indisponible",
    'ar': "الشاشة غير متوفرة",
  },
  'registration': {'fr': "Inscription", 'ar': "التسجيل"},
  'join_with_qr': {
    'fr': "Rejoindre avec un QR code",
    'ar': "انضمام عبر رمز QR",
  },
  'invite_invalid_or_expired': {
    'fr': "Invitation invalide ou expirée.",
    'ar': "الدعوة غير صالحة أو منتهية الصلاحية.",
  },
  'scan_again': {'fr': "Scanner à nouveau", 'ar': "امسح مرة أخرى"},
  'join_admin_farm': {
    'fr': "Vous rejoignez l'exploitation de {admin}.",
    'ar': "أنت تنضم إلى مزرعة {admin}.",
  },
  'registration_name': {'fr': "Votre nom", 'ar': "اسمك"},
  'registration_name_invalid': {
    'fr': "Le nom doit contenir entre 2 et 60 caractères.",
    'ar': "يجب أن يتراوح الاسم بين حرفين و60 حرفًا.",
  },
  'registration_invite_rejected': {
    'fr': "Cette invitation est invalide, expirée ou déjà utilisée.",
    'ar': "الدعوة غير صالحة أو منتهية أو مستخدمة بالفعل.",
  },
  'registration_submit': {'fr': "Rejoindre", 'ar': "انضم"},
  'name_entry_title': {'fr': "Vérification du nom", 'ar': "التحقق من الاسم"},
  'name_entry_prompt': {
    'fr': "Saisissez votre nom pour continuer.",
    'ar': "أدخل اسمك للمتابعة.",
  },
  'continue': {'fr': "Continuer", 'ar': "متابعة"},
  'qr_name_mismatch': {
    'fr': "Le nom ne correspond pas au compte. Vérifiez-le et réessayez.",
    'ar': "الاسم لا يطابق الحساب. تحقق منه وحاول مرة أخرى.",
  },
  'qr_expired': {
    'fr': "QR code expiré, demandez-en un nouveau à votre administrateur.",
    'ar': "انتهت صلاحية رمز QR، اطلب رمزًا جديدًا من المسؤول.",
  },
  'qr_used': {
    'fr': "Ce QR code a déjà été utilisé.",
    'ar': "تم استخدام رمز QR هذا من قبل.",
  },
  'qr_unknown': {
    'fr': "QR code inconnu ou invalide. Demandez-en un nouveau.",
    'ar': "رمز QR غير معروف أو غير صالح. اطلب رمزًا جديدًا.",
  },
  'qr_scanner_error': {
    'fr': "Impossible de lire le QR code. Réessayez.",
    'ar': "تعذرت قراءة رمز QR. حاول مرة أخرى.",
  },
  'scan_prompt': {
    'fr': "Scannez le QR code d'invitation fourni par votre administrateur",
    'ar': "اسكاني رمز الدعوة اللي عطاهولك المسؤول",
  },
  'scan_btn': {'fr': "Scanner le QR d'invitation", 'ar': "اسكاني رمز الدعوة"},
  'scan_hint': {
    'fr': "Scannez le QR code d'invitation",
    'ar': "اسكاني رمز دعوة الانضمام",
  },
  'qr_cancelled': {
    'fr': "Lecture annulée. Vous pouvez réessayer.",
    'ar': "تم إلغاء القراءة. يمكنك المحاولة مجددًا.",
  },
  'nav_home': {'fr': "Accueil", 'ar': "الرئيسية"},
  'nav_cows': {'fr': "Animaux", 'ar': "الحيوانات"},
  'nav_tasks': {'fr': "Tâches", 'ar': "المهام"},
  'nav_nfc': {'fr': "NFC", 'ar': "NFC"},
  'feeding': {'fr': "Ration journalière", 'ar': "الماكلة اليومية"},
  'tasks_title': {'fr': "Mes tâches", 'ar': "مهامي"},
  'tasks_empty': {'fr': "Aucune tâche", 'ar': "ما فما حتى مهمة"},
  'tasks_load_error': {
    'fr': "Impossible de charger les tâches. Réessayez.",
    'ar': "تعذّر تحميل المهام. عاود المحاولة.",
  },
  'tasks_retry': {'fr': "Réessayer", 'ar': "عاود المحاولة"},
  'task_mark_done': {'fr': "Confirmer", 'ar': "تأكيد"},
  'task_plan': {'fr': "Plan de la tâche", 'ar': "خطة المهمة"},
  'task_type_sell': {'fr': "Vendre", 'ar': "البيع"},
  'task_type_vet': {'fr': "Vétérinaire", 'ar': "الطبيب البيطري"},
  'task_type_butcher': {'fr': "Boucher", 'ar': "الجزّار"},
  'task_type_check_weight': {'fr': "Peser", 'ar': "إعادة الوزن"},
  'task_type_custom': {'fr': "Personnalisée", 'ar': "مهمة مخصصة"},
  'task_title_sell': {'fr': "Vendre la vache", 'ar': "بيع البقرة"},
  'task_title_vet': {
    'fr': "Emmener la vache chez le vétérinaire",
    'ar': "أخذ البقرة إلى الطبيب البيطري",
  },
  'task_title_butcher': {
    'fr': "Envoyer la vache à la boucherie",
    'ar': "إرسال البقرة إلى الجزّار",
  },
  'task_title_check_weight': {
    'fr': "Vérifier le poids de la vache",
    'ar': "إعادة وزن البقرة",
  },
  'task_title_custom': {'fr': "Nouvelle tâche", 'ar': "مهمة جديدة"},
  'task_plan_sell': {
    'fr': "Préparer la vache pour la vente.\n"
        "Vérifier son état et ses documents.\n"
        "Informer l’administrateur une fois la vente effectuée.",
    'ar': "حضّر البقرة للبيع.\n"
        "تحقّق من حالتها ووثائقها.\n"
        "أعلم المسؤول بعد إتمام البيع.",
  },
  'task_plan_vet': {
    'fr': "Emmener la vache chez le vétérinaire.\n"
        "Expliquer les symptômes ou le motif de consultation.\n"
        "Suivre les recommandations du vétérinaire et faire un compte rendu.",
    'ar': "خذ البقرة إلى الطبيب البيطري.\n"
        "اشرح الأعراض أو سبب الاستشارة.\n"
        "اتبع توصيات الطبيب وقدّم تقريرًا.",
  },
  'task_plan_butcher': {
    'fr': "Organiser le transport de la vache à la boucherie.\n"
        "Vérifier les documents nécessaires.\n"
        "Informer l’administrateur une fois la démarche effectuée.",
    'ar': "نظّم نقل البقرة إلى الجزّار.\n"
        "تحقّق من الوثائق اللازمة.\n"
        "أعلم المسؤول بعد إتمام الإجراء.",
  },
  'task_plan_check_weight': {
    'fr': "Peser la vache.\n"
        "Noter son poids.\n"
        "Vérifier son état corporel.\n"
        "Signaler toute anomalie.",
    'ar': "زِن البقرة.\n"
        "سجّل وزنها.\n"
        "تحقّق من حالة جسمها.\n"
        "أبلغ عن أي أمر غير طبيعي.",
  },
  'task_confirm': {'fr': "Confirmer", 'ar': "تأكيد"},
  'task_confirm_title': {'fr': "Confirmer la tâche", 'ar': "تأكيد المهمة"},
  'task_confirm_message': {
    'fr': "Confirmez-vous que cette tâche est terminée ?",
    'ar': "هل تؤكد إتمام هذه المهمة؟",
  },
  'task_weigh_cow': {
    'fr': "Peser la vache",
    'ar': "زِن البقرة",
  },
  'task_weight_banner': {
    'fr': "Consignes de l’administrateur",
    'ar': "تعليمات المسؤول",
  },
  'task_previous_weight': {
    'fr': "Ancien poids",
    'ar': "الوزن السابق",
  },
  'task_weight_unchanged_title': {
    'fr': "Le poids est inchangé, confirmer ?",
    'ar': "الوزن لم يتغيّر، هل تؤكد؟",
  },
  'task_weight_unchanged_message': {
    'fr': "Confirmez-vous que le poids actuel est correct ?",
    'ar': "هل تؤكد أن الوزن الحالي صحيح؟",
  },
  'task_weight_range_invalid': {
    'fr': "Le poids doit être compris entre 30 et 1 000 kg.",
    'ar': "يجب أن يكون الوزن بين 30 و1000 كغ.",
  },
  'task_profile_load_title': {
    'fr': "Profil indisponible",
    'ar': "الملف الشخصي غير متاح",
  },
  'task_profile_load_error': {
    'fr': "Impossible de charger le profil de cette vache.",
    'ar': "تعذّر تحميل الملف الشخصي لهذه البقرة.",
  },
  'task_fallback_confirm': {
    'fr': "Confirmer la tâche sans modifier le profil",
    'ar': "تأكيد المهمة دون تعديل الملف الشخصي",
  },
  'task_weight_saved_pending': {
    'fr':
        "Le poids est enregistré, mais la tâche reste à confirmer. Réessayez.",
    'ar': "تم حفظ الوزن، لكن المهمة ما زالت غير مؤكدة. حاول مجددًا.",
  },
  'task_weight_optional': {
    'fr': "Poids (kg), facultatif",
    'ar': "الوزن (كغ)، اختياري",
  },
  'task_note_optional': {
    'fr': "Note, facultative",
    'ar': "ملاحظة، اختيارية",
  },
  'task_weight_invalid': {
    'fr': "Saisissez un poids valide entre 0 et 1 500 kg.",
    'ar': "أدخل وزنًا صالحًا بين 0 و1500 كغ.",
  },
  'task_completed_success': {
    'fr': "Tâche confirmée. Votre administrateur a été informé.",
    'ar': "تم تأكيد المهمة وإبلاغ المسؤول.",
  },
  'tasks_home_title': {
    'fr': "Tâches à faire",
    'ar': "المهام المطلوب إنجازها",
  },
  'tasks_home_empty': {
    'fr': "Aucune tâche pour le moment",
    'ar': "لا توجد مهام في الوقت الحالي",
  },
  'tasks_view_all': {'fr': "Voir tout", 'ar': "عرض الكل"},
  'task_due_at': {'fr': "À faire avant", 'ar': "آخر أجل"},
  'task_overdue': {'fr': "En retard depuis", 'ar': "فات أجلها منذ"},
  'task_cow': {'fr': "Bovin", 'ar': "البقرة"},
  'task_update_error': {
    'fr': "Impossible de mettre à jour la tâche. Réessayez.",
    'ar': "تعذّر تحديث المهمة. عاود المحاولة.",
  },
  'got_it': {'fr': "Compris", 'ar': "فهمت"},
  'nfc_title': {'fr': "Scanner la boucle NFC", 'ar': "اسكاني بطاقة NFC"},
  'nfc_absent': {
    'fr': "Cet appareil ne prend pas en charge le NFC.",
    'ar': "هذا الجهاز لا يدعم NFC.",
  },
  'nfc_disabled': {
    'fr': "Le NFC est désactivé. Activez-le dans les paramètres.",
    'ar': "NFC معطّل. فعّله من الإعدادات.",
  },
  'nfc_timeout': {
    'fr': "Délai de lecture NFC dépassé. Réessayez.",
    'ar': "انتهت مهلة قراءة NFC. حاول مجددًا.",
  },
  'nfc_busy': {
    'fr': "Une lecture NFC est déjà en cours.",
    'ar': "توجد قراءة NFC جارية بالفعل.",
  },
  'nfc_read_failed': {
    'fr': "Impossible de lire la puce NFC. Réessayez.",
    'ar': "تعذّرت قراءة شريحة NFC. حاول مجددًا.",
  },
  'nfc_open_settings': {
    'fr': "Ouvrir les paramètres NFC",
    'ar': "افتح إعدادات NFC",
  },
  'nfc_cancelled': {
    'fr': "Lecture NFC annulée.",
    'ar': "تم إلغاء قراءة NFC.",
  },
  'nfc_tag_registered': {
    'fr': "Cette boucle est déjà enregistrée.",
    'ar': "هذه الحلقة مسجّلة بالفعل.",
  },
  'nfc_tag_elsewhere': {
    'fr': "Cette boucle est déjà enregistrée ailleurs.",
    'ar': "هذه الحلقة مسجّلة لدى مسؤول آخر.",
  },
  'nfc_tag_not_found': {
    'fr': "Aucune vache n’est enregistrée avec cette boucle.",
    'ar': "لا توجد بقرة مسجّلة بهذه الحلقة.",
  },
  'open_profile': {
    'fr': "Ouvrir le profil",
    'ar': "فتح الملف",
  },
  'nfc_retry': {'fr': "Réessayer", 'ar': "عاود"},
  'nfc_step': {
    'fr': "Approchez le téléphone de la boucle de l'animal.",
    'ar': "قرّب التليفون من بطاقة الحيوان.",
  },
  'nfc_wait': {'fr': "En attente de la boucle…", 'ar': "نستنّاو في البطاقة…"},
  'nfc_help': {
    'fr': "Gardez le téléphone immobile pendant la lecture.",
    'ar': "خلّي التليفون ثابت وقت القراءة.",
  },
  'cancel': {'fr': "Annuler", 'ar': "إلغاء"},
  'settings': {'fr': "Paramètres", 'ar': "الإعدادات"},
  'notifications_title': {'fr': "Notifications", 'ar': "الإشعارات"},
  'notifications_description': {
    'fr': "Recevoir une notification pour les nouvelles tâches.",
    'ar': "تلقي إشعار عند وصول مهام جديدة.",
  },
  'notifications_permission_title': {
    'fr': "Activer les notifications",
    'ar': "تفعيل الإشعارات",
  },
  'notifications_permission_description': {
    'fr':
        "Autorisez les notifications pour être averti des nouvelles tâches, même lorsque l’application est fermée.",
    'ar':
        "اسمح بالإشعارات لتلقي تنبيه عند وصول مهام جديدة، حتى عند إغلاق التطبيق.",
  },
  'notifications_enable': {'fr': "Activer", 'ar': "تفعيل"},
  'notifications_later': {'fr': "Plus tard", 'ar': "لاحقًا"},
  'notifications_permission_hint': {
    'fr':
        "Les notifications sont désactivées dans les paramètres du téléphone.",
    'ar': "الإشعارات معطّلة في إعدادات الهاتف.",
  },
  'notifications_open_settings': {
    'fr': "Paramètres",
    'ar': "الإعدادات",
  },
  'notifications_check_now': {
    'fr': "Vérifier maintenant",
    'ar': "تحقّق الآن",
  },
  'notifications_error': {
    'fr': "Impossible de mettre à jour les notifications.",
    'ar': "تعذّر تحديث الإشعارات.",
  },
  'notifications_service_active': {
    'fr': "Surveillance active",
    'ar': "المراقبة مفعّلة",
  },
  'notifications_service_inactive': {
    'fr': "La surveillance en arrière-plan est arrêtée.",
    'ar': "المراقبة في الخلفية متوقفة.",
  },
  'notifications_background_title': {
    'fr': "Autoriser l'exécution en arrière-plan",
    'ar': "السماح بالعمل في الخلفية",
  },
  'notifications_background_description': {
    'fr':
        "Pour recevoir rapidement les tâches, autorisez l'activité en arrière-plan et le démarrage automatique dans les paramètres de batterie du téléphone.",
    'ar':
        "لتلقي المهام بسرعة، اسمح بالنشاط في الخلفية والتشغيل التلقائي من إعدادات بطارية الهاتف.",
  },
  'notifications_background_open': {
    'fr': "Paramètres batterie",
    'ar': "إعدادات البطارية",
  },
  'notifications_session_expired': {
    'fr': "Reconnectez-vous pour recevoir les notifications.",
    'ar': "أعد تسجيل الدخول لتلقي الإشعارات.",
  },
  'reconnect': {'fr': "Se reconnecter", 'ar': "إعادة تسجيل الدخول"},
  'task_already_done': {
    'fr': "Tâche déjà terminée",
    'ar': "تم إكمال المهمة بالفعل",
  },

  // ---------- Add cow screen (same names as the mock)
  'new_cow': {'fr': "Nouvelle vache", 'ar': "بقرة جديدة"},
  'save': {'fr': "Enregistrer", 'ar': "سجّل"},
  'nfc_linked': {'fr': "Boucle liée ✅", 'ar': "البطاقة مربوطة ✅"},
  'age': {'fr': "Âge", 'ar': "العمر"},
  'weight': {'fr': "Poids", 'ar': "الوزن"},
  'months': {'fr': "mois", 'ar': "شهر"},
  'years': {'fr': "ans", 'ar': "سنين"},
  'kg': {'fr': "kg", 'ar': "كغ"},
  'holstein': {'fr': "Holstein", 'ar': "هولشتاين"},
  'montbeliarde': {'fr': "Montbeliarde", 'ar': "مونبيليارد"},
  'brune': {'fr': "Brune", 'ar': "براون"},
  'frisonne': {'fr': "Frisonne", 'ar': "فريزون"},

  // ---------- Cow detail screen (same names as the mock)
  'appetite': {'fr': "Appétit", 'ar': "الشهية"},
  'confidence': {'fr': "Confiance du modèle", 'ar': "نسبة الثقة"},
  'model_note': {
    'fr': "Analyse par intelligence artificielle (Random Forest)",
    'ar': "تحليل بالذكاء الاصطناعي (Random Forest)",
  },
  'advice_increasing': {
    'fr': "Elle mange plus que d'habitude.",
    'ar': "تاكل أكثر م العادة.",
  },
  'advice_stable': {
    'fr': "Elle mange comme d'habitude.",
    'ar': "تاكل كيما العادة.",
  },
  'advice_decreasing': {
    'fr': "Elle mange moins. Surveillez-la.",
    'ar': "تاكل أقل. حطّ عينك عليها.",
  },
  'profile': {'fr': "Profil", 'ar': "البروفيل"},
  'rfid': {'fr': "Boucle NFC", 'ar': "بطاقة NFC"},
  'modify': {'fr': "Modifier", 'ar': "بدّل"},
  'edit_profile': {'fr': "Modifier le profil", 'ar': "بدّل البروفيل"},
  'edit_profile_hint': {
    'fr': "Changez l'âge, le poids ou la race de cette vache.",
    'ar': "بدّل العمر ولا الوزن ولا السلالة متاع هالبقرة.",
  },
  'profile_saved': {'fr': "Profil mis à jour ✅", 'ar': "تحدّث البروفيل ✅"},
  'live_now': {'fr': "En direct", 'ar': "مباشر"},
  'no_reading': {
    'fr': "Aucune lecture pour le moment.",
    'ar': "ما فما حتى قراءة توّا.",
  },
  'trend_14d': {
    'fr': "Tendance de l'appétit (14 jours)",
    'ar': "اتجاه الشهية (14 يوم)",
  },
  'no_trend_data': {
    'fr': "Pas encore de données d'appétit.",
    'ar': "ما فما حتى بيانات شهية لتوّا.",
  },
  'search_by_day': {'fr': "Rechercher un jour", 'ar': "لوّج على نهار"},
  'pick_day': {'fr': "Choisir une date", 'ar': "اختار تاريخ"},
  'no_data_day': {
    'fr': "Aucune donnée pour ce jour.",
    'ar': "ما فما حتى بيانات للنهار هذا.",
  },
};
