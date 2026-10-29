import 'package:flutter/material.dart';

/// Whether the app is used by touch: the theme pads tap targets then.
bool usesTouch(ThemeData theme) =>
    theme.materialTapTargetSize == MaterialTapTargetSize.padded;
