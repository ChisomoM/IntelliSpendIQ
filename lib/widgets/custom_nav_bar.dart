import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:c_template_app/utils/screen_size.dart';

class CustomBottomAppBar extends StatefulWidget {
  const CustomBottomAppBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });
  final int currentIndex;
  final void Function(int) onTap;

  @override
  // ignore: library_private_types_in_public_api
  _CustomBottomAppBarState createState() => _CustomBottomAppBarState();
}

class _CustomBottomAppBarState extends State<CustomBottomAppBar> {
  Color _getColorForIndex(int index) {
    return widget.currentIndex == index
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;
  }

  FontWeight _getFontWeightForIndex(int index) {
    return widget.currentIndex == index ? FontWeight.w700 : FontWeight.w400;
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shadowColor: const Color.fromRGBO(24, 24, 62, 0.151),
      elevation: 10,
      notchMargin: 75,
      height: hp(70),
      shape: const CircularNotchedRectangle(),
      // color: const Color.fromARGB(217, 221, 5, 5),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          //HOME
          MaterialButton(
            minWidth: 40,
            onPressed: () => widget.onTap(0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home,
                  color: _getColorForIndex(0),
                ),
                Text(
                  'Home',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: _getFontWeightForIndex(0),
                    color: _getColorForIndex(0),
                  ),
                ),
              ],
            ),
          ),
          //LOANS
          MaterialButton(
            minWidth: 40,
            onPressed: () => widget.onTap(1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books_rounded,
                  color: _getColorForIndex(1),
                ),
                Text(
                  'Packages',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: _getFontWeightForIndex(1),
                    color: _getColorForIndex(1),
                  ),
                ),
              ],
            ),
          ),

          //More
          MaterialButton(
            minWidth: 40,
            onPressed: () => widget.onTap(2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //Menu
                Icon(
                  Icons.menu,
                  color: _getColorForIndex(2),
                ),

                Text(
                  'More',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: _getFontWeightForIndex(2),
                    color: _getColorForIndex(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
