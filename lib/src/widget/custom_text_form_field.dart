import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:get/get.dart';


class CustomTextFormField extends StatelessWidget {
  final bool? enabled;
  final bool? filled;
  final TextEditingController? controller;
  final bool? showError;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final bool? obscureText;
  final RxBool? isObscure;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final TextInputType? keyboardType;

  const CustomTextFormField({
    super.key,
    this.controller,
    this.enabled = true,
    this.filled = true,
    this.showError = false,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.onChanged,
    this.obscureText = false,
    this.isObscure,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.labelText,
    this.hintText,
    this.errorText,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final errorStyle = showError ?? false
        ? Theme.of(context).inputDecorationTheme.errorStyle
        : const TextStyle(
            height: 0,
            fontSize: 0,
          );

    return TextFormField(
      controller: controller,
      autocorrect: false,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      obscureText: obscureText ?? false,
      validator: validator,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            width: 0,
            style: BorderStyle.none,
          ),
        ),
        floatingLabelStyle: Get.textTheme.bodyLarge,
        enabled: enabled ?? true,
        filled: filled ?? enabled,
        fillColor: Color(0xfff3f4ff),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
        isDense: true,
        labelText: labelText,
        labelStyle: TextStyle(color: Color(0xffadb0b6)),
        hintText: hintText ?? labelText,
        hintStyle: TextStyle(color: Color(0xffadb0b6)),
        errorText: errorText,
        errorStyle: errorStyle,
        prefixIcon: prefixIcon,
        prefixIconColor: ColorApp.primaryDarkColor,
        suffixIcon: suffixIcon ??
            (isObscure != null
                ? IconButton(
                    onPressed: () {
                      isObscure?.value = !(isObscure?.value ?? false);
                    },
                    icon: isObscure?.value ?? false
                        ? Icon(
                            Icons.visibility_off_outlined,
                            size: 24,
                          )
                        : Icon(
                            Icons.visibility_outlined,
                            size: 24,
                          ),
                  )
                : null),
        suffixIconColor: ColorApp.primaryDarkColor,
      ),
    );
  }
}

class DropDownForm extends StatefulWidget {
  final TextEditingController? controller;
  final List<String> variable;
  final String hintText;
  final String defaultValue;
  final ValueChanged<String> onSelected;
  final TextInputType? keyboardType;

  const DropDownForm({super.key, 
    this.controller,
    required this.variable,
    required this.defaultValue,
    required this.hintText,
    required this.onSelected,
    this.keyboardType,
  });

  @override
  _DropDownFormState createState() => _DropDownFormState();
}

class _DropDownFormState extends State<DropDownForm> {
  late String selectedVariable;

  @override
  void initState() {
    super.initState();
    selectedVariable = widget.variable.contains(widget.defaultValue)
        ? widget.defaultValue
        : widget.variable[0];
  }

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton(
              value: selectedVariable,
              items: widget.variable
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(code),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedVariable = value!;
                  widget.onSelected(value);
                });
              },
            ),
            VerticalDivider(
              width: 1,
              indent: 10,
              endIndent: 10,
              color: Color(0xFFADB0B6),
            ),
            SizedBox(width: 12,),
          ],
        ),
      ),
      hintText: widget.hintText,
    );
  }
}
