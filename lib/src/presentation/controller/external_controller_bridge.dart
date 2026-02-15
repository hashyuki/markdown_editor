import 'package:flutter/material.dart';

class ExternalControllerBridge {
  ExternalControllerBridge({
    required TextEditingController internalController,
    TextEditingController? externalController,
  }) : _internalController = internalController,
       _externalController = externalController {
    _internalController.addListener(_syncToExternalController);
    _externalController?.addListener(_syncFromExternalController);
  }

  final TextEditingController _internalController;
  TextEditingController? _externalController;

  void updateExternalController(TextEditingController? externalController) {
    if (_externalController == externalController) {
      return;
    }
    _externalController?.removeListener(_syncFromExternalController);
    _externalController = externalController;
    _externalController?.addListener(_syncFromExternalController);
    _syncFromExternalController();
  }

  void dispose() {
    _externalController?.removeListener(_syncFromExternalController);
    _internalController.removeListener(_syncToExternalController);
  }

  void _syncFromExternalController() {
    final externalController = _externalController;
    if (externalController == null) {
      return;
    }
    if (_internalController.value == externalController.value) {
      return;
    }
    _internalController.value = externalController.value;
  }

  void _syncToExternalController() {
    final externalController = _externalController;
    if (externalController == null) {
      return;
    }
    if (externalController.value == _internalController.value) {
      return;
    }
    externalController.value = _internalController.value;
  }
}
