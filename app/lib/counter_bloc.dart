import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

abstract class CounterEvent extends Equatable {
  const CounterEvent();

  @override
  List<Object> get props => [];
}

class CounterIncremented extends CounterEvent {}

class CounterDecremented extends CounterEvent {}

class CounterState extends Equatable {
  final int count;

  const CounterState(this.count);

  @override
  List<Object> get props => [count];
}

class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterState(0)) {
    on<CounterIncremented>((event, emit) {
      emit(CounterState(state.count + 1));
    });

    on<CounterDecremented>((event, emit) {
      emit(CounterState(state.count - 1));
    });
  }
}