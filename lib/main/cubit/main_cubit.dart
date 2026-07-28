import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:c_template_app/utils/enums.dart';
part 'main_state.dart';

class MainCubit extends Cubit<MainState> {
  MainCubit() : super(const MainState());

  void changeTab(int index) {
    emit(state.copyWith(currentIndex: index));
  }
}
