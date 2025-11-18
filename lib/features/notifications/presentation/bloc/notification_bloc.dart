import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/usecases/get_notifications_usecase.dart';
import '../../domain/usecases/stream_notifications_usecase.dart';
import '../../domain/usecases/mark_notification_read_usecase.dart';
import '../../../../core/errors/failures.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final GetNotificationsUseCase getNotificationsUseCase;
  final StreamNotificationsUseCase streamNotificationsUseCase;
  final MarkNotificationReadUseCase markNotificationReadUseCase;
  StreamSubscription<Either<Failure, List<NotificationEntity>>>? _notificationSubscription;

  NotificationBloc({
    required this.getNotificationsUseCase,
    required this.streamNotificationsUseCase,
    required this.markNotificationReadUseCase,
  }) : super(NotificationInitial()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<StreamNotifications>(_onStreamNotifications);
    on<MarkAsRead>(_onMarkAsRead);
    on<MarkAllAsRead>(_onMarkAllAsRead);
  }

  @override
  Future<void> close() {
    _notificationSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    
    final result = await getNotificationsUseCase(event.parentId, limit: event.limit);
    
    result.fold(
      (failure) => emit(NotificationError(message: failure.message)),
      (notifications) => emit(NotificationLoaded(notifications: notifications)),
    );
  }

  void _onStreamNotifications(
    StreamNotifications event,
    Emitter<NotificationState> emit,
  ) {
    // Cancel previous subscription if any
    _notificationSubscription?.cancel();
    
    print('📡 [NotificationBloc] Starting stream for parent: ${event.parentId}');
    emit(NotificationLoading());
    
    _notificationSubscription = streamNotificationsUseCase(event.parentId, childId: event.childId).listen(
      (result) {
        result.fold(
          (failure) {
            print('❌ [NotificationBloc] Stream error: ${failure.message}');
            emit(NotificationError(message: failure.message));
          },
          (notifications) {
            print('✅ [NotificationBloc] Received ${notifications.length} notifications');
            emit(NotificationLoaded(notifications: notifications));
          },
        );
      },
      onError: (error, stackTrace) {
        print('❌ [NotificationBloc] Stream onError: $error');
        print('❌ [NotificationBloc] Stack trace: $stackTrace');
        emit(NotificationError(message: error.toString()));
      },
      cancelOnError: false,
    );
  }

  Future<void> _onMarkAsRead(
    MarkAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    final result = await markNotificationReadUseCase(event.parentId, event.childId, event.notificationId);
    
    result.fold(
      (failure) => emit(NotificationError(message: failure.message)),
      (_) {
        // Update local state
        if (state is NotificationLoaded) {
          final currentNotifications = (state as NotificationLoaded).notifications;
          final updatedNotifications = currentNotifications.map((notification) {
            if (notification.id == event.notificationId) {
              return notification.copyWith(isRead: true, readAt: DateTime.now());
            }
            return notification;
          }).toList();
          emit(NotificationLoaded(notifications: updatedNotifications));
        }
      },
    );
  }

  Future<void> _onMarkAllAsRead(
    MarkAllAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    // Implementation for marking all as read
    // This would require a use case for markAllAsRead
  }
}

