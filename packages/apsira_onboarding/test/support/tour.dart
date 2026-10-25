// A sample tour for the layout check and the golden: Spanish-length words,
// a scene, and a step with two paths of taps.
import 'package:apsira_onboarding/apsira_onboarding.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

/// A still scene drawn from tokens: a card with a title bar and two lines.
Widget _scene(BuildContext context, Animation<double> progress) {
  final t = ApsiraTheme.of(context);
  Widget bar(double width, Color color) => Container(
    width: width,
    height: 10,
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(5),
    ),
  );
  return FadeTransition(
    opacity: progress,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [bar(160, t.accentFill), bar(200, t.ink3), bar(120, t.ink3)],
    ),
  );
}

final sampleTour = [
  TourStepData(
    title: 'Tus viajes, en un solo sitio',
    body:
        'Cada viaje guarda sus reservas, sus documentos y su presupuesto, '
        'y funciona sin conexión.',
    summary: 'Una lista de viajes con sus fechas',
    scene: _scene,
  ),
  TourStepData(
    title: 'Importa un paquete de viaje',
    body:
        'Abre Viajes y toca Importar paquete; después elige el archivo que '
        'te enviaron.',
    summary: 'El menú de Viajes con Importar paquete',
    scene: _scene,
    taps: const [
      ['Viajes', 'Importar paquete'],
      ['Ajustes y preferencias del viaje', 'Copias de seguridad', 'Restaurar'],
    ],
  ),
  TourStepData(
    title: 'Copias de seguridad',
    body: 'Elige una carpeta y cada noche se guarda una copia de todo.',
    summary: 'La carpeta de copias elegida',
    scene: _scene,
  ),
];

/// The tour as first open plays it: on the ground, in the gutter, with
/// Back to the language step and Show me more on the last step.
Widget sampleTourScreen({int initialStep = 0}) => Scaffold(
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(ApsiraSpacing.screenGutter),
      child: TourPlayer(
        steps: sampleTour,
        initialStep: initialStep,
        keyPrefix: 'firstOpen',
        onBackFromFirst: () {},
        onSkip: () {},
        onDone: () {},
        secondaryLabel: 'Enséñame más',
        onSecondary: () {},
        tapPathLabel: (path) => 'Toca ${path.join(', luego ')}',
      ),
    ),
  ),
);
