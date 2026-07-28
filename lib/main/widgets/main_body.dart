import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:c_template_app/main/cubit/main_cubit.dart';
import 'package:c_template_app/home/view/home_page.dart';

/// {@template main_body}
/// Body of the MainPage.
/// {@endtemplate}
class MainBody extends StatefulWidget {
  /// {@macro main_body}
  const MainBody({super.key});
  static const int homeTabIndex = 0;
  static const int contentTabIndex = 1;
  static const int moreTabIndex = 2;
  @override
  State<MainBody> createState() => _MainBodyState();
}

class _MainBodyState extends State<MainBody> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainCubit, MainState>(
      builder: (context, state) {
        return PopScope(
          canPop: state.currentIndex == MainBody.homeTabIndex,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && state.currentIndex != MainBody.homeTabIndex) {
              context.read<MainCubit>().changeTab(MainBody.homeTabIndex);
            }
          },
          child: Scaffold(
            body: _buildBody(state.currentIndex),
            bottomNavigationBar: BottomNavigationBar(
              elevation: 2,
              selectedFontSize: 12,
              currentIndex: state.currentIndex,
              onTap: (index) => context.read<MainCubit>().changeTab(index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.library_books_rounded),
                  label: 'Content',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu),
                  label: 'More',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(int index) {
    switch (index) {
      case MainBody.homeTabIndex:
        return const HomePage();
      case MainBody.contentTabIndex:
        return const Center(child: Text('Content'));
      case MainBody.moreTabIndex:
        return const Center(child: Text('More'));
      default:
        return const HomePage();
    }
  }
}
