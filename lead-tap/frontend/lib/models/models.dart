// Models representing API response objects.
library;

class AppUser {
  final String id;
  final String email;
  final String name;
  final String whatsappNumber;
  final String gsheetId;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.whatsappNumber,
    required this.gsheetId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: (json['name'] as String?) ?? '',
        whatsappNumber: (json['whatsapp_number'] as String?) ?? '',
        gsheetId: (json['gsheet_id'] as String?) ?? '',
      );

  bool get hasWhatsApp => whatsappNumber.isNotEmpty;

  AppUser copyWith({String? whatsappNumber}) => AppUser(
        id: id,
        email: email,
        name: name,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
        gsheetId: gsheetId,
      );
}

class Event {
  final String id;
  final String name;
  final String whatsappMessage;
  final String mediaUrl;
  final int leadCount;
  final DateTime createdAt;

  const Event({
    required this.id,
    required this.name,
    required this.whatsappMessage,
    required this.mediaUrl,
    required this.leadCount,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        name: json['name'] as String,
        whatsappMessage: (json['whatsapp_message'] as String?) ?? '',
        mediaUrl: (json['media_url'] as String?) ?? '',
        leadCount: (json['lead_count'] as int?) ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class Lead {
  final String id;
  final String name;
  final String mobileNumber;
  final String email;
  final String comment;
  final DateTime createdAt;

  const Lead({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.email,
    required this.comment,
    required this.createdAt,
  });

  factory Lead.fromJson(Map<String, dynamic> json) => Lead(
        id: json['id'] as String,
        name: json['name'] as String,
        mobileNumber: json['mobile_number'] as String,
        email: (json['email'] as String?) ?? '',
        comment: (json['comment'] as String?) ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
