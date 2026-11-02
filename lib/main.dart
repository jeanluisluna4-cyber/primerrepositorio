import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MiBlocDeNotasApp());
}

class MiBlocDeNotasApp extends StatefulWidget {
  const MiBlocDeNotasApp({super.key});

  @override
  State<MiBlocDeNotasApp> createState() => MiBlocDeNotasAppState();

  static MiBlocDeNotasAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<MiBlocDeNotasAppState>();
  }
}

class MiBlocDeNotasAppState extends State<MiBlocDeNotasApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dev Notes Pro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF818CF8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF090D16),
      ),
      home: const PantallaNotas(),
    );
  }
}

class Nota {
  String titulo;
  String contenido;
  DateTime fecha;
  bool completada;
  String categoria;
  String prioridad;
  bool fijada;

  Nota({
    required this.titulo,
    required this.contenido,
    required this.fecha,
    this.completada = false,
    this.categoria = 'General',
    this.prioridad = 'Media',
    this.fijada = false,
  });

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'contenido': contenido,
        'fecha': fecha.toIso8601String(),
        'completada': completada,
        'categoria': categoria,
        'prioridad': prioridad,
        'fijada': fijada,
      };

  factory Nota.fromJson(Map<String, dynamic> json) => Nota(
        titulo: json['titulo'] ?? '',
        contenido: json['contenido'] ?? '',
        fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : DateTime.now(),
        completada: json['completada'] ?? false,
        categoria: json['categoria'] ?? 'General',
        prioridad: json['prioridad'] ?? 'Media',
        fijada: json['fijada'] ?? false,
      );
}

class PantallaNotas extends StatefulWidget {
  const PantallaNotas({super.key});

  @override
  State<PantallaNotas> createState() => _PantallaNotasState();
}

class _PantallaNotasState extends State<PantallaNotas> {
  List<Nota> notas = [];
  String textoBusqueda = '';
  bool buscando = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> categoriasDisponibles = [
    'General',
    'Trabajo',
    'Personal',
    'Código',
    'Ideas'
  ];
  final List<String> prioridadesDisponibles = ['Alta', 'Media', 'Baja'];

  @override
  void initState() {
    super.initState();
    _cargarNotas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarNotas() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notasString = prefs.getString('mis_notas');
    if (notasString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(notasString);
        setState(() {
          notas = jsonList.map((item) => Nota.fromJson(item)).toList();
          _ordenarNotas();
        });
      } catch (e) {
        notas = [];
      }
    }
  }

  Future<void> _guardarNotas() async {
    _ordenarNotas();
    final prefs = await SharedPreferences.getInstance();
    final String notasString =
        jsonEncode(notas.map((n) => n.toJson()).toList());
    await prefs.setString('mis_notas', notasString);
  }

  void _ordenarNotas() {
    notas.sort((a, b) {
      // 1. Las completadas siempre van al fondo
      if (a.completada != b.completada) {
        return a.completada ? 1 : -1;
      }
      // 2. Las fijadas van primero (si ninguna o ambas están completadas)
      if (a.fijada != b.fijada) {
        return a.fijada ? -1 : 1;
      }
      // 3. Peso por prioridad
      int pesoPrioridad(String p) {
        if (p == 'Alta') return 3;
        if (p == 'Media') return 2;
        return 1;
      }
      final pA = pesoPrioridad(a.prioridad);
      final pB = pesoPrioridad(b.prioridad);
      if (pA != pB) {
        return pB.compareTo(pA);
      }
      // 4. Por fecha más reciente
      return b.fecha.compareTo(a.fecha);
    });
  }

  Color _obtenerColorCategoria(String categoria) {
    switch (categoria) {
      case 'Trabajo':
        return Colors.blueAccent;
      case 'Personal':
        return Colors.greenAccent;
      case 'Código':
        return Colors.purpleAccent;
      case 'Ideas':
        return Colors.orangeAccent;
      default:
        return const Color(0xFF818CF8);
    }
  }

  Color _obtenerColorPrioridad(String prioridad) {
    switch (prioridad) {
      case 'Alta':
        return Colors.redAccent;
      case 'Media':
        return Colors.amberAccent;
      case 'Baja':
        return Colors.tealAccent;
      default:
        return Colors.grey;
    }
  }

  void _exportarRespaldo() {
    final jsonString = jsonEncode(notas.map((n) => n.toJson()).toList());
    Clipboard.setData(ClipboardData(text: jsonString));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Respaldo JSON copiado al portapapeles!')),
    );
  }

  void _importarRespaldoDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar Respaldo'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Pega aquí tu código JSON...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              try {
                final List<dynamic> jsonList = jsonDecode(controller.text);
                setState(() {
                  notas = jsonList.map((item) => Nota.fromJson(item)).toList();
                  _ordenarNotas();
                });
                _guardarNotas();
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Notas restauradas con éxito!')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('JSON inválido, verifica los datos.')),
                );
              }
            },
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  void _limpiarCompletadas() {
    setState(() {
      notas.removeWhere((n) => n.completada);
    });
    _guardarNotas();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tareas completadas eliminadas')),
    );
  }

  void _abrirEditor({Nota? nota, int? index}) {
    final tituloController =
        TextEditingController(text: nota != null ? nota.titulo : '');
    final contenidoController =
        TextEditingController(text: nota != null ? nota.contenido : '');
    String categoriaSeleccionada = nota != null ? nota.categoria : 'General';
    String prioridadSeleccionada = nota != null ? nota.prioridad : 'Media';
    bool fijadaSeleccionada = nota != null ? nota.fijada : false;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (contextState, setStateDialog) {
            final textoActual = contenidoController.text;
            final numCaracteres = textoActual.length;
            final numPalabras = textoActual.trim().isEmpty
                ? 0
                : textoActual.trim().split(RegExp(r'\s+')).length;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF131C2E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              title: Text(
                nota == null ? '// Nueva Tarea' : '// Editar Tarea',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF818CF8),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: tituloController,
                      decoration: InputDecoration(
                        labelText: 'Título',
                        filled: true,
                        fillColor:
                            isDark ? const Color(0xFF090D16) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contenidoController,
                      maxLines: 4,
                      onChanged: (val) {
                        setStateDialog(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        filled: true,
                        fillColor:
                            isDark ? const Color(0xFF090D16) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$numPalabras palabras | $numCaracteres caracteres',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Fijar al inicio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: fijadaSeleccionada,
                      activeThumbColor: const Color(0xFF6366F1),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setStateDialog(() {
                          fijadaSeleccionada = val;
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Prioridad',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: prioridadesDisponibles.map((prio) {
                        final seleccionada = prioridadSeleccionada == prio;
                        return ChoiceChip(
                          label: Text(prio),
                          selected: seleccionada,
                          selectedColor:
                              _obtenerColorPrioridad(prio).withValues(alpha: 0.3),
                          backgroundColor:
                              isDark ? const Color(0xFF090D16) : Colors.grey[200],
                          labelStyle: TextStyle(
                            color: seleccionada
                                ? _obtenerColorPrioridad(prio)
                                : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            setStateDialog(() {
                              prioridadSeleccionada = prio;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Categoría',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: categoriasDisponibles.map((cat) {
                        final seleccionada = categoriaSeleccionada == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: seleccionada,
                          selectedColor: const Color(0xFF6366F1),
                          backgroundColor:
                              isDark ? const Color(0xFF090D16) : Colors.grey[200],
                          labelStyle: TextStyle(
                            color: seleccionada ? Colors.white : Colors.grey,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            setStateDialog(() {
                              categoriaSeleccionada = cat;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (tituloController.text.trim().isEmpty &&
                        contenidoController.text.trim().isEmpty) {
                      return;
                    }

                    setState(() {
                      if (nota == null) {
                        notas.add(
                          Nota(
                            titulo: tituloController.text,
                            contenido: contenidoController.text,
                            fecha: DateTime.now(),
                            completada: false,
                            categoria: categoriaSeleccionada,
                            prioridad: prioridadSeleccionada,
                            fijada: fijadaSeleccionada,
                          ),
                        );
                      } else {
                        notas[index!] = Nota(
                          titulo: tituloController.text,
                          contenido: contenidoController.text,
                          fecha: DateTime.now(),
                          completada: nota.completada,
                          categoria: categoriaSeleccionada,
                          prioridad: prioridadSeleccionada,
                          fijada: fijadaSeleccionada,
                        );
                      }
                    });

                    _guardarNotas();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _eliminarNota(int index, Nota notaEliminada) {
    HapticFeedback.heavyImpact();
    setState(() {
      notas.removeAt(index);
    });
    _guardarNotas();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nota eliminada'),
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: const Color(0xFF818CF8),
          onPressed: () {
            setState(() {
              notas.insert(index, notaEliminada);
              _ordenarNotas();
            });
            _guardarNotas();
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final notasFiltradas = notas.where((nota) {
      final tituloMatch =
          nota.titulo.toLowerCase().contains(textoBusqueda.toLowerCase());
      final contenidoMatch =
          nota.contenido.toLowerCase().contains(textoBusqueda.toLowerCase());
      return tituloMatch || contenidoMatch;
    }).toList();

    final completadas = notas.where((n) => n.completada).length;
    final total = notas.length;
    final progreso = total == 0 ? 0.0 : completadas / total;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  buscando
                      ? Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Buscar notas...',
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF131C2E)
                                  : Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onChanged: (value) {
                              setState(() {
                                textoBusqueda = value;
                              });
                            },
                          ),
                        )
                      : const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jean Luis ',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 2,
                                color: Color(0xFF818CF8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Mis Notas & Tareas',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                            buscando ? Icons.close : Icons.search_rounded,
                            color: const Color(0xFF818CF8)),
                        onPressed: () {
                          setState(() {
                            buscando = !buscando;
                            if (!buscando) {
                              textoBusqueda = '';
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: const Color(0xFF818CF8)),
                        onPressed: () {
                          MiBlocDeNotasApp.of(context)?.toggleTheme();
                        },
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Color(0xFF818CF8)),
                        onSelected: (value) {
                          if (value == 'exportar') _exportarRespaldo();
                          if (value == 'importar') _importarRespaldoDialog();
                          if (value == 'limpiar') _limpiarCompletadas();
                        },
                        itemBuilder: (ctxMenu) => [
                          const PopupMenuItem(
                              value: 'exportar',
                              child: Text('Copiar Respaldo (JSON)')),
                          const PopupMenuItem(
                              value: 'importar',
                              child: Text('Restaurar Respaldo')),
                          const PopupMenuItem(
                              value: 'limpiar',
                              child: Text('Eliminar completadas')),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (total > 0 && !buscando)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                    ],
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Progreso general',
                              style: TextStyle(fontSize: 13)),
                          Text(
                            '$completadas de $total completadas',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF818CF8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progreso,
                          backgroundColor: isDark
                              ? const Color(0xFF090D16)
                              : Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF6366F1)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: notasFiltradas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: (isDark
                                  ? const Color(0xFF131C2E)
                                  : Colors.grey[200])!,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.note_alt_outlined,
                                size: 48, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            buscando
                                ? 'No se encontraron resultados'
                                : 'Sin registros todavía',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      itemCount: notasFiltradas.length,
                      itemBuilder: (ctxList, index) {
                        final nota = notasFiltradas[index];
                        final realIndex = notas.indexOf(nota);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            decoration: BoxDecoration(
                              color: nota.completada
                                  ? (isDark
                                      ? const Color(0xFF131C2E)
                                          .withValues(alpha: 0.4)
                                      : Colors.grey[100])
                                  : (isDark
                                      ? const Color(0xFF131C2E)
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                if (!isDark && !nota.completada)
                                  BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3))
                              ],
                              border: Border.all(
                                color: nota.fijada && !nota.completada
                                    ? const Color(0xFF818CF8).withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _abrirEditor(
                                    nota: nota, index: realIndex),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: nota.completada,
                                          activeColor: const Color(0xFF6366F1),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          onChanged: (bool? value) {
                                            HapticFeedback.lightImpact();
                                            setState(() {
                                              nota.completada =
                                                  value ?? false;
                                              _ordenarNotas();
                                            });
                                            _guardarNotas();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      if (nota.fijada)
                                                        const Padding(
                                                          padding: EdgeInsets.only(right: 6),
                                                          child: Icon(
                                                            Icons.push_pin_rounded,
                                                            size: 14,
                                                            color: Color(0xFF818CF8),
                                                          ),
                                                        ),
                                                      Expanded(
                                                        child: Text(
                                                          nota.titulo.isEmpty
                                                              ? 'Sin título'
                                                              : nota.titulo,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            decoration:
                                                                nota.completada
                                                                    ? TextDecoration
                                                                        .lineThrough
                                                                    : null,
                                                            color: nota.completada
                                                                ? Colors.grey
                                                                : null,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Container(
                                                      margin: const EdgeInsets.only(right: 6),
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: _obtenerColorPrioridad(nota.prioridad)
                                                            .withValues(alpha: 0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        nota.prioridad,
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: _obtenerColorPrioridad(nota.prioridad),
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: _obtenerColorCategoria(
                                                                nota.categoria)
                                                            .withValues(alpha: 0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8),
                                                      ),
                                                      child: Text(
                                                        nota.categoria,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              _obtenerColorCategoria(
                                                                  nota.categoria),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            if (nota.contenido.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                nota.contenido,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  decoration:
                                                      nota.completada
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                  color: nota.completada
                                                      ? Colors.grey
                                                      : Colors.grey[400],
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '${nota.fecha.day}/${nota.fecha.month}/${nota.fecha.year}',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: 'monospace',
                                                      color: Colors.grey),
                                                ),
                                                GestureDetector(
                                                  onTap: () => _eliminarNota(
                                                      realIndex, nota),
                                                  child: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 18,
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _abrirEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Nota',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}