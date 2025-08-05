import 'package:intl/intl.dart';

String formatChatTime(DateTime dateTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

  if (messageDate == today) {
    return DateFormat('HH:mm').format(dateTime);
  } else if (messageDate == yesterday) {
    return 'Dün';
  } else if (now.difference(dateTime).inDays < 7) {
    return DateFormat('EEEE', 'tr_TR').format(dateTime);
  } else {
    return DateFormat('dd.MM.yyyy').format(dateTime);
  }
}

String formatMessageTime(DateTime dateTime) {
  return DateFormat('HH:mm').format(dateTime);
}

