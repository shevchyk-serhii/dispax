import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';

void main() {
  group('CreateRideFormBloc tags', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'TagAdded appends a normalized tag',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const TagAdded('  Urgent ')),
      expect: () => [
        isA<CreateRideFormState>().having((s) => s.tags, 'tags', ['Urgent']),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'TagAdded ignores a case-insensitive duplicate',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc
        ..add(const TagAdded('Urgent'))
        ..add(const TagAdded('urgent')),
      expect: () => [
        isA<CreateRideFormState>().having((s) => s.tags, 'tags', ['Urgent']),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'TagAdded ignores a blank tag',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const TagAdded('   ')),
      expect: () => <CreateRideFormState>[],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'TagRemoved removes the tag',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc
        ..add(const TagAdded('Urgent'))
        ..add(const TagAdded('Cash'))
        ..add(const TagRemoved('Urgent')),
      expect: () => [
        isA<CreateRideFormState>().having((s) => s.tags, 'tags', ['Urgent']),
        isA<CreateRideFormState>().having((s) => s.tags, 'tags', [
          'Urgent',
          'Cash',
        ]),
        isA<CreateRideFormState>().having((s) => s.tags, 'tags', ['Cash']),
      ],
    );

    test('tags are part of state props (equality)', () {
      final base = CreateRideFormState.initial();
      final a = base.copyWith(tags: const ['x']);
      final b = base.copyWith(tags: const ['y']);
      expect(a == b, isFalse);
      expect(a == base.copyWith(tags: const ['x']), isTrue);
    });
  });
}
