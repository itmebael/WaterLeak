import 'package:flutter/material.dart';
import 'package:waterleak/ui/shared/globals.dart';
// import 'package:provider/provider.dart';

class TextFieldWidget extends StatelessWidget {
  final String hintText;
  final IconData prefixIconData;
  final IconData? suffixIconData;
  final bool obscureText;
  final ValueChanged<String> onChanged;

  TextFieldWidget({
    required this.hintText,
    required this.prefixIconData,
    this.suffixIconData,
    required this.obscureText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // final model = Provider.of<HomeModel>(context); // Removed undefined Provider usage

    return TextField(
      onChanged: onChanged,
      obscureText: obscureText,
      cursorColor: Global.mediumBlue,
      style: TextStyle(
        color: Global.mediumBlue,
        fontSize: 14.0,
      ),
      decoration: InputDecoration(
        labelStyle: TextStyle(color: Global.mediumBlue),
        focusColor: Global.mediumBlue,
        filled: true,
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Global.mediumBlue),
        ),
        labelText: hintText,
        prefixIcon: Icon(
          prefixIconData,
          size: 18,
          color: Global.mediumBlue,
        ),
        suffixIcon: GestureDetector(
          onTap: () {
            // model.isVisible = !model.isVisible; // Removed undefined 'model' usage
          },
          child: Icon(
            suffixIconData,
            size: 18,
            color: Global.mediumBlue,
          ),
        ),
      ),
    );
  }
}
