import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/formatos.dart';
import '../../data/models/cita.dart';
import '../../data/models/perfil.dart';
import 'resumen_reporte.dart';

class ExportarReporte {
  static List<String> get _cabecera => [
        'Código', 'Fecha', 'Hora', 'Turno', 'Paciente', 'DNI', 'Código univ.', 'Tipo', 'Área', 'Profesional',
        'Consultorio', 'Estado', 'Asistió', 'Hora de llegada', 'Atendido el', 'Derivado a', 'Derivación externa',
        'Motivo derivación', 'Motivo consulta',
      ];

  static List<String> _fila(Cita c) => [
        c.codigo,
        Formatos.fechaCorta(c.fecha),
        Formatos.horaSql(c.horaInicio),
        c.turnoEtiqueta,
        c.pacienteNombre,
        c.pacienteDni ?? '',
        c.pacienteCodigo ?? '',
        tiposUsuario[c.pacienteTipo] ?? '',
        c.especialidadNombre,
        c.doctorNombre,
        c.consultorio ?? '',
        c.estado.etiqueta,
        switch (c.asistio) { true => 'Sí', false => 'No', null => '' },
        c.horaLlegada != null ? Formatos.fechaHora(c.horaLlegada!) : '',
        c.atendidaEn != null ? Formatos.fechaHora(c.atendidaEn!) : '',
        c.derivadoANombre ?? '',
        c.derivacionExterna ?? '',
        c.motivoDerivacion ?? '',
        c.motivo ?? '',
      ];

  static String _nombreArchivo(DateTime desde, DateTime hasta, String ext) =>
      'reporte_citas_${Formatos.iso(desde)}_a_${Formatos.iso(hasta)}.$ext';

  /// CSV compatible con Excel (UTF-8 con BOM para que respete tildes y ñ).
  static Future<void> csv(List<Cita> citas, DateTime desde, DateTime hasta) async {
    String esc(String v) => '"${v.replaceAll('"', '""').replaceAll('\n', ' ')}"';
    final sb = StringBuffer('﻿')..writeln(_cabecera.map(esc).join(','));
    for (final c in citas) {
      sb.writeln(_fila(c).map(esc).join(','));
    }
    final nombre = _nombreArchivo(desde, hasta, 'csv');
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(utf8.encode(sb.toString()), mimeType: 'text/csv', name: nombre)],
      fileNameOverrides: [nombre],
      subject: 'Reporte de citas UniSalud',
    ));
  }

  static Future<void> pdf(List<Cita> citas, DateTime desde, DateTime hasta, {required String generadoPor}) async {
    final r = ResumenReporte(citas);
    pw.ThemeData? tema;
    try {
      tema = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.nunitoSansRegular(),
        bold: await PdfGoogleFonts.nunitoSansBold(),
      );
    } catch (_) {
      tema = null; // sin internet: usa la fuente por defecto
    }

    const verde = PdfColor.fromInt(0xFF0E7C86);
    final doc = pw.Document(title: 'Reporte de citas', author: 'UniSalud');

    pw.Widget titulo(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(t, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: verde)),
        );

    pw.Widget tabla(List<String> cab, List<List<String>> filas) => pw.TableHelper.fromTextArray(
          headers: cab,
          data: filas,
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: verde),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: tema,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('UniSalud · Reporte de citas',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: verde)),
          pw.Text('Del ${Formatos.fechaCorta(desde)} al ${Formatos.fechaCorta(hasta)}'),
        ]),
        pw.Text('Generado el ${Formatos.fechaHora(DateTime.now())} por $generadoPor',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Divider(color: verde),
      ]),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9)),
      ),
      build: (ctx) => [
        titulo('Resumen general'),
        tabla(
          ['Total', 'Atendidas', 'Pendientes', 'Confirmadas', 'No asistieron', 'Canceladas', '% asistencia', 'Derivaciones'],
          [
            [
              '${r.total}',
              '${r.cuenta(EstadoCita.atendida)}',
              '${r.cuenta(EstadoCita.pendiente)}',
              '${r.cuenta(EstadoCita.confirmada)}',
              '${r.cuenta(EstadoCita.noAsistio)}',
              '${r.cuenta(EstadoCita.cancelada)}',
              '${r.tasaAsistencia.toStringAsFixed(1)} %',
              '${r.totalDerivaciones}',
            ]
          ],
        ),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              titulo('Citas por área'),
              tabla(['Área', 'Citas'], [for (final e in ResumenReporte.ordenar(r.porArea)) [e.key, '${e.value}']]),
              titulo('Citas por turno'),
              tabla(['Turno', 'Citas'], [for (final e in ResumenReporte.ordenar(r.porTurno)) [e.key, '${e.value}']]),
            ]),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              titulo('Derivaciones'),
              r.derivaciones.isEmpty
                  ? pw.Text('Sin derivaciones en el periodo')
                  : tabla(['Destino', 'Pacientes'],
                      [for (final e in ResumenReporte.ordenar(r.derivaciones)) [e.key, '${e.value}']]),
              titulo('Por tipo de paciente'),
              tabla(['Tipo', 'Citas'],
                  [for (final e in ResumenReporte.ordenar(r.porTipoPaciente)) [tiposUsuario[e.key] ?? e.key, '${e.value}']]),
            ]),
          ),
        ]),
        titulo('Productividad por profesional'),
        tabla(
          ['Profesional', 'Área', 'Total', 'Atendidas', 'No asistieron', 'Canceladas'],
          [
            for (final p in r.porProfesional.values.toList()..sort((a, b) => b.total.compareTo(a.total)))
              [p.nombre, p.area, '${p.total}', '${p.atendidas}', '${p.inasistencias}', '${p.canceladas}'],
          ],
        ),
        titulo('Detalle de citas'),
        tabla(
          ['Código', 'Fecha', 'Hora', 'Turno', 'Paciente', 'DNI', 'Área', 'Profesional', 'Estado', 'Asistió', 'Atendido el', 'Derivado a'],
          [
            for (final c in citas)
              [
                c.codigo,
                Formatos.fechaCorta(c.fecha),
                Formatos.horaSql(c.horaInicio),
                c.turnoEtiqueta,
                c.pacienteNombre,
                c.pacienteDni ?? '',
                c.especialidadNombre,
                c.doctorNombre,
                c.estado.etiqueta,
                switch (c.asistio) { true => 'Sí', false => 'No', null => '-' },
                c.atendidaEn != null ? Formatos.fechaHora(c.atendidaEn!) : '-',
                c.derivadoANombre ?? c.derivacionExterna ?? '-',
              ],
          ],
        ),
      ],
    ));

    await Printing.sharePdf(bytes: await doc.save(), filename: _nombreArchivo(desde, hasta, 'pdf'));
  }
}
