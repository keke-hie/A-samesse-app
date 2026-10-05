import 'package:flutter/material.dart';

class AuthScreenShell extends StatelessWidget {
  static const Color actionColor = Color(0xFFE99FA3);
  static const Color headingColor = Color(0xFF75464A);

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;

  const AuthScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4E3E2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shellWidth = constraints.maxWidth > 520
                ? 440.0
                : constraints.maxWidth;
            final headerHeight = (constraints.maxHeight * 0.34)
                .clamp(190.0, 245.0)
                .toDouble();

            return Center(
              child: SizedBox(
                width: shellWidth,
                height: constraints.maxHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      SizedBox(
                        height: headerHeight,
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFEFA9AA), Color(0xFFD9858D)],
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (leading != null)
                                Positioned(top: 8, left: 10, child: leading!),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.storefront_outlined,
                                      color: Colors.white,
                                      size: 25,
                                    ),
                                    const SizedBox(height: 7),
                                    const Text(
                                      "A'samesse",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'serif',
                                        fontSize: 32,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'MARCHÉ LOCAL',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(25),
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, panelConstraints) =>
                                SingleChildScrollView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: panelConstraints.maxHeight,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        28,
                                        24,
                                        26,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            title,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: headingColor,
                                              fontSize: 21,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            subtitle,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF9B7779),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          child,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.autofillHints,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _isObscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(24));
    const borderColor = Color(0xFFE4B8BA);

    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _isObscured,
      autofillHints: widget.autofillHints,
      cursorColor: AuthScreenShell.actionColor,
      style: const TextStyle(color: Color(0xFF5E4547), fontSize: 13),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: Color(0xFFC9AEB0), fontSize: 12),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 14,
        ),
        suffixIcon: widget.obscureText
            ? IconButton(
                tooltip: _isObscured
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                onPressed: () => setState(() => _isObscured = !_isObscured),
                icon: Icon(
                  _isObscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFFB99A9C),
                  size: 18,
                ),
              )
            : null,
        border: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: AuthScreenShell.actionColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
