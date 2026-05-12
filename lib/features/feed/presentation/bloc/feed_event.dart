// lib/features/feed/presentation/bloc/feed_event.dart

import 'package:equatable/equatable.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();
}

class FeedStarted extends FeedEvent {
  const FeedStarted();
  @override
  List<Object?> get props => [];
}

class FeedRefreshRequested extends FeedEvent {
  const FeedRefreshRequested();
  @override
  List<Object?> get props => [];
}

class FeedLoadMoreRequested extends FeedEvent {
  const FeedLoadMoreRequested();
  @override
  List<Object?> get props => [];
}
