import 'package:flutter/services.dart';

/// Formatter genérico de máscara.
/// Use '#' no [mask] para indicar onde entram os dígitos.
/// Ex: '(##) #####-####', '###.###.###-##', '#####-###'
class MaskedInputFormatter extends TextInputFormatter {
  final String mask;
  final String separator;

  MaskedInputFormatter(this.mask, {this.separator = '#'});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    final buffer = StringBuffer();
    int digitIndex = 0;

    for (int i = 0; i < mask.length && digitIndex < digits.length; i++) {
      if (mask[i] == separator) {
        buffer.write(digits[digitIndex]);
        digitIndex++;
      } else {
        buffer.write(mask[i]);
      }
    }

    final masked = buffer.toString();

    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }
}

class InputMasks {
  static MaskedInputFormatter telefone() =>
      MaskedInputFormatter('(##) #####-####');

  static MaskedInputFormatter cpf() => MaskedInputFormatter('###.###.###-##');

  static MaskedInputFormatter cnpj() =>
      MaskedInputFormatter('##.###.###/####-##');

  static MaskedInputFormatter cep() => MaskedInputFormatter('#####-###');
}