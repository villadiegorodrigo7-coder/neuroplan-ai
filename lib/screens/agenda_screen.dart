import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/agenda_event.dart';
import '../models/task.dart';
import '../services/agenda_store.dart';
import '../services/tasks_service.dart';

const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _diasFull = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const _meses = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
const _frecuencias = {'unica':'Una sola vez','diaria':'Todos los días','semanal':'Cada semana','personalizada':'Días seleccionados'};
const _colores = {
  'urgenteImportante': Color(0xFFFF6B6B),
  'importanteNoUrgente': Color(0xFF8C7CFF),
  'urgenteNoImportante': Color(0xFFFFB74D),
  'niUrgenteNiImportante': Color(0xFFB0AEC5),
};
const _bloques = [
  _Bloque('manana','Mañana','Antes de las 12 p. m.',Icons.wb_sunny_outlined),
  _Bloque('tarde','Tarde','De 12 a 6 p. m.',Icons.wb_twilight),
  _Bloque('noche','Noche','Desde las 6 p. m.',Icons.nights_stay_outlined),
];
class _Bloque {
  final String clave, titulo, rango;
  final IconData icono;
  const _Bloque(this.clave,this.titulo,this.rango,this.icono);
}
DateTime _fecha(DateTime d) => DateTime(d.year,d.month,d.day);
String _clave(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
Color _colorTarea(Task t) => _colores[t.cuadrante] ?? const Color(0xFF8D9BC8);

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}
class _AgendaScreenState extends State<AgendaScreen> {
  bool _loading = true, _mensual = false;
  DateTime _seleccion = _fecha(DateTime.now());
  DateTime _mes = DateTime(DateTime.now().year,DateTime.now().month);
  final _tasks = TasksService.instance;

  @override
  void initState() {
    super.initState();
    AgendaStore.instance.addListener(_refresh);
    _tasks.addListener(_refresh);
    _cargar();
  }
  Future<void> _cargar() async {
    try { await Future.wait([AgendaStore.instance.cargar(),_tasks.cargar()]); } catch (_) {}
    if (mounted) setState(() => _loading=false);
  }
  void _refresh() { if (mounted) setState(() {}); }
  @override
  void dispose() {
    AgendaStore.instance.removeListener(_refresh);
    _tasks.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _addEvent() async {
    final title=TextEditingController();
    DateTime dia=_seleccion;
    TimeOfDay inicio=TimeOfDay.now();
    int duracion=60;
    String frecuencia='unica';
    bool aviso=true;
    final dias=<int>{};
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,setD)=>AlertDialog(
        title:const Text('Nuevo compromiso'),
        content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:title,autofocus:true,decoration:const InputDecoration(labelText:'Actividad')),
          ListTile(contentPadding:EdgeInsets.zero,title:const Text('Fecha de inicio'),
            subtitle:Text(DateFormat('dd/MM/yyyy').format(dia)),trailing:const Icon(Icons.calendar_today),
            onTap:() async { final p=await showDatePicker(context:ctx,initialDate:dia,firstDate:DateTime(2020),lastDate:DateTime(2100)); if(p!=null)setD(()=>dia=p); }),
          Row(children:[
            Expanded(child:InkWell(onTap:() async {final p=await showTimePicker(context:ctx,initialTime:inicio);if(p!=null)setD(()=>inicio=p);},
              child:InputDecorator(decoration:const InputDecoration(labelText:'Hora de inicio'),child:Text(inicio.format(ctx))))),
            const SizedBox(width:8),
            Expanded(child:DropdownButtonFormField<int>(value:duracion,decoration:const InputDecoration(labelText:'Duración'),
              items:const [15,30,45,60,90,120,180].map((m)=>DropdownMenuItem(value:m,child:Text(m<60?'${m} minutos':'${m~/60} h${m%60==0?'':' ${m%60} min'}'))).toList(),
              onChanged:(v)=>setD(()=>duracion=v??60))),
          ]),
          DropdownButtonFormField<String>(value:frecuencia,decoration:const InputDecoration(labelText:'Se repite'),
            items:_frecuencias.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
            onChanged:(v)=>setD(()=>frecuencia=v??'unica')),
          if(frecuencia=='personalizada') Wrap(spacing:3,children:[for(var i=0;i<7;i++)FilterChip(
            label:Text(_dias[i]),selected:dias.contains(i+1),onSelected:(v)=>setD(()=>v?dias.add(i+1):dias.remove(i+1)))]),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Activar aviso'),value:aviso,onChanged:(v)=>setD(()=>aviso=v)),
          const Text('Los compromisos recurrentes siguen activos hasta que los elimines.',style:TextStyle(fontSize:12)),
        ]))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
          FilledButton(onPressed:()=>title.text.trim().isNotEmpty&&(frecuencia!='personalizada'||dias.isNotEmpty)?Navigator.pop(ctx,true):null,child:const Text('Guardar')),
        ],
      )));
    if(ok==true&&mounted){
      final s=DateTime(dia.year,dia.month,dia.day,inicio.hour,inicio.minute);
      final evento=AgendaEvent(id:const Uuid().v4(),title:title.text.trim(),date:s,endDate:s.add(Duration(minutes:duracion)),
        aviso:aviso,frecuencia:frecuencia,diasSemana:dias.toList()..sort());
      final conflicto=_buscarConflicto(evento);
      if(conflicto!=null){
        await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Horario ocupado'),
          content:Text('Este intervalo se cruza con ${conflicto.title}. Revisa los horarios antes de guardar.'),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Entendido'))]));
      } else {
        AgendaStore.instance.agregar(evento);
        setState(()=>{_seleccion=_fecha(dia);_mes=DateTime(dia.year,dia.month);});
      }
    }
    title.dispose();
  }

  AgendaEvent? _buscarConflicto(AgendaEvent nuevo){
    for(final actual in AgendaStore.instance.eventos.where((e)=>e.id!=nuevo.id)){
      final desde=nuevo.date.isAfter(actual.date)?nuevo.date:actual.date;
      final inicio=_fecha(desde);
      final dias=nuevo.frecuencia=='unica'?[_fecha(nuevo.date)]:actual.frecuencia=='unica'?[_fecha(actual.date)]:List.generate(7,(i)=>inicio.add(Duration(days:i)));
      for(final d in dias){
        final ni=nuevo.inicioEn(d),nf=nuevo.finEn(d),ai=actual.inicioEn(d),af=actual.finEn(d);
        if(ni!=null&&nf!=null&&ai!=null&&af!=null&&ni.isBefore(af)&&ai.isBefore(nf))return actual;
      }
    }
    return null;
  }
  String _mensajeConflicto(AgendaEvent nuevo, AgendaEvent conflicto) {
    final inicioPedido = nuevo.date;
    final finPedido = nuevo.endDate;
    final inicioOcupado = DateTime(inicioPedido.year, inicioPedido.month,
      inicioPedido.day, conflicto.date.hour, conflicto.date.minute);
    final finOcupado = inicioOcupado.add(conflicto.duracion);
    final libreAntes = inicioOcupado.difference(inicioPedido).inMinutes;
    final cruceInicio = inicioPedido.isAfter(inicioOcupado) ? inicioPedido : inicioOcupado;
    final cruceFin = finPedido.isBefore(finOcupado) ? finPedido : finOcupado;
    final minutosCruce = cruceFin.difference(cruceInicio).inMinutes;
    final detalle = libreAntes > 0
      ? 'Puedes utilizar el tramo de §{DateFormat('HH:mm').format(inicioPedido)} a §{DateFormat('HH:mm').format(inicioOcupado)}: son $libreAntes minutos libres. El resto se cruza con el compromiso existente.'
      : 'El horario solicitado coincide con un periodo que ya está ocupado.';
    return 'Se cruza con "§{conflicto.title}", de §{DateFormat('HH:mm').format(inicioOcupado)} a §{DateFormat('HH:mm').format(finOcupado)}. $detalle (solapamiento: $minutosCruce minutos).';
  }
  Future<void> _eliminar(AgendaEvent e) async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Eliminar compromiso'),
      content:Text('¿Eliminar "${e.title}" y sus repeticiones?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Eliminar'))]));
    if(ok==true)AgendaStore.instance.eliminar(e.id);
  }
  void _moverPeriodo(int delta){
    setState((){
      if(_mensual){_mes=DateTime(_mes.year,_mes.month+delta);}
      else {_seleccion=_seleccion.add(Duration(days:delta*7));_mes=DateTime(_seleccion.year,_seleccion.month);}
    });
  }
  List<DateTime> _diasCalendario(){
    if(!_mensual){
      final lunes=_seleccion.subtract(Duration(days:_seleccion.weekday-1));
      return List.generate(7,(i)=>lunes.add(Duration(days:i)));
    }
    final primero=DateTime(_mes.year,_mes.month,1);
    final inicio=primero.subtract(Duration(days:primero.weekday-1));
    final cantidad=((primero.weekday-1+DateTime(_mes.year,_mes.month+1,0).day+6)~/7)*7;
    return List.generate(cantidad,(i)=>inicio.add(Duration(days:i)));
  }
  Widget _calendario(ColorScheme s){
    final dias=_diasCalendario();
    final titulo=_mensual?'${_meses[_mes.month-1][0].toUpperCase()}${_meses[_mes.month-1].substring(1)} ${_mes.year}':
      '${DateFormat('d MMM', 'es').format(dias.first)} – ${DateFormat('d MMM yyyy','es').format(dias.last)}';
    return Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:s.surfaceContainerHighest,borderRadius:BorderRadius.circular(18)),
      child:Column(children:[
        Row(children:[
          const Expanded(child:Text('Mis compromisos',style:TextStyle(fontSize:17,fontWeight:FontWeight.w700))),
          IconButton(onPressed:()=>_moverPeriodo(-1),icon:const Icon(Icons.chevron_left)),
          Text(titulo,style:const TextStyle(fontWeight:FontWeight.w600)),
          IconButton(onPressed:()=>_moverPeriodo(1),icon:const Icon(Icons.chevron_right)),
        ]),
        SegmentedButton<bool>(segments:const[
          ButtonSegment(value:false,label:Text('Semana'),icon:Icon(Icons.view_week_outlined)),
          ButtonSegment(value:true,label:Text('Mes'),icon:Icon(Icons.calendar_month_outlined)),
        ],selected:{_mensual},onSelectionChanged:(v)=>setState(()=>{_mensual=v.first;_mes=DateTime(_seleccion.year,_seleccion.month);})),
        const SizedBox(height:12),
        Row(children:[for(final d in _dias)Expanded(child:Center(child:Text(d,style:TextStyle(fontSize:11,color:s.onSurface.withValues(alpha:.65)))))]),
        const SizedBox(height:6),
        GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:dias.length,
          gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,mainAxisSpacing:4,crossAxisSpacing:3,childAspectRatio:.9),
          itemBuilder:(ctx,i){
            final d=dias[i],sel=_fecha(d)==_seleccion,actual=_fecha(d)==_fecha(DateTime.now());
            final tiene=AgendaStore.instance.eventosEnDia(d).isNotEmpty;
            final delMes=d.month==_mes.month;
            return InkWell(borderRadius:BorderRadius.circular(9),onTap:()=>setState((){_seleccion=_fecha(d);_mes=DateTime(d.year,d.month);}),
              child:Container(decoration:BoxDecoration(color:sel?s.primaryContainer:null,borderRadius:BorderRadius.circular(9),
                border:actual&&!sel?Border.all(color:s.primary):null),
                child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                  Text('${d.day}',style:TextStyle(fontSize:13,fontWeight:sel||actual?FontWeight.bold:FontWeight.normal,
                    color:!delMes&&_mensual?s.onSurface.withValues(alpha:.25):sel?s.onPrimaryContainer:s.onSurface)),
                  const SizedBox(height:3),
                  Container(width:6,height:6,decoration:BoxDecoration(shape:BoxShape.circle,color:tiene?s.tertiary:Colors.transparent)),
                ])));
          }),
        Row(children:[
          Container(width:7,height:7,decoration:BoxDecoration(color:s.tertiary,shape:BoxShape.circle)),
          const SizedBox(width:6),Text('Fecha con compromisos',style:TextStyle(fontSize:11,color:s.onSurface.withValues(alpha:.65))),
          const Spacer(),TextButton(onPressed:()=>setState(()=>_seleccion=_fecha(DateTime.now())),child:const Text('Hoy')),
        ]),
      ]));
  }

  String _bloqueHora(DateTime d)=>d.hour<12?'manana':d.hour<18?'tarde':'noche';
  Future<void> _agregarTarea(String bloque) async {
    final f=_clave(_seleccion);
    final pendientes=_tasks.tasks.where((t)=>!t.done&&!(t.fecha==f&&t.bloque==bloque)).toList();
    final elegida=await showModalBottomSheet<Task>(context:context,showDragHandle:true,builder:(ctx)=>SafeArea(
      child:pendientes.isEmpty?const Padding(padding:EdgeInsets.all(24),child:Text('No hay tareas pendientes. Agrégalas desde la matriz de Tareas.')):
      ListView(shrinkWrap:true,children:[
        const Padding(padding:EdgeInsets.all(16),child:Text('Selecciona una tarea de la matriz',style:TextStyle(fontWeight:FontWeight.bold))),
        for(final t in pendientes)ListTile(leading:Container(width:10,height:10,decoration:BoxDecoration(color:_colorTarea(t),shape:BoxShape.circle)),
          title:Text(t.title),subtitle:Text(t.cuadrante??'Sin clasificar'),onTap:()=>Navigator.pop(ctx,t)),
      ])));
    if(elegida!=null)_tasks.llevarAFecha(elegida,f,bloque);
  }
  Widget _jornada(ColorScheme s){
    final eventos=AgendaStore.instance.eventosEnDia(_seleccion);
    final fecha=_clave(_seleccion);
    final tareas=_tasks.tasks.where((t)=>t.fecha==fecha).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Padding(padding:const EdgeInsets.fromLTRB(2,20,2,12),child:Text(
        '${_diasFull[_seleccion.weekday-1]} ${DateFormat('d MMMM yyyy','es').format(_seleccion)}',
        style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700))),
      for(final b in _bloques)
        Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(13),
          decoration:BoxDecoration(color:s.surfaceContainerHighest,borderRadius:BorderRadius.circular(16)),
          child:Column(children:[
            Row(children:[Icon(b.icono,color:s.secondary,size:19),const SizedBox(width:8),
              Expanded(child:Text(b.titulo,style:const TextStyle(fontWeight:FontWeight.w700))),
              Text(b.rango,style:TextStyle(fontSize:10,color:s.onSurface.withValues(alpha:.6))),
              IconButton(tooltip:'Agregar tarea de la matriz',onPressed:()=>_agregarTarea(b.clave),icon:Icon(Icons.add_circle_outline,color:s.primary)),
            ]),
            for(final e in eventos.where((e)=>_bloqueHora(e.date)==b.clave))
              Row(children:[
                Icon(Icons.event_available,color:s.tertiary,size:16),const SizedBox(width:7),
                SizedBox(width:100,child:Text('${DateFormat('HH:mm').format(e.date)}–${DateFormat('HH:mm').format(e.endDate)}',style:TextStyle(fontSize:11,color:s.onSurface.withValues(alpha:.65)))),
                Expanded(child:Text(e.title,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600))),
                if(e.aviso)Icon(Icons.notifications_active,size:14,color:s.primary),
                IconButton(visualDensity:VisualDensity.compact,onPressed:()=>_eliminar(AgendaStore.instance.porId(e.id)!),icon:const Icon(Icons.delete_outline,size:17)),
              ]),
            for(final t in tareas.where((t)=>t.bloque==b.clave))
              Row(children:[
                Container(width:8,height:8,decoration:BoxDecoration(color:_colorTarea(t),shape:BoxShape.circle)),
                const SizedBox(width:8),
                GestureDetector(onTap:()=>_tasks.alternar(t),child:Icon(t.done?Icons.check_circle:Icons.circle_outlined,color:t.done?s.primary:s.onSurface.withValues(alpha:.6),size:19)),
                const SizedBox(width:8),
                Expanded(child:Text(t.title,style:TextStyle(fontSize:13,decoration:t.done?TextDecoration.lineThrough:null))),
                IconButton(visualDensity:VisualDensity.compact,tooltip:'Quitar de este día',onPressed:()=>_tasks.quitarDeHoy(t),icon:const Icon(Icons.close,size:17)),
              ]),
            if(eventos.where((e)=>_bloqueHora(e.date)==b.clave).isEmpty&&tareas.where((t)=>t.bloque==b.clave).isEmpty)
              Align(alignment:Alignment.centerLeft,child:Padding(padding:const EdgeInsets.only(top:4),child:Text('Espacio disponible para organizar tu día.',style:TextStyle(fontSize:12,color:s.onSurface.withValues(alpha:.6))))),
          ])),
    ]);
  }

  @override
  Widget build(BuildContext context){
    final s=Theme.of(context).colorScheme;
    return Scaffold(appBar:AppBar(title:const Text('Agenda')),
      floatingActionButton:FloatingActionButton(onPressed:_addEvent,backgroundColor:s.primary,child:const Icon(Icons.add)),
      body:_loading?const Center(child:CircularProgressIndicator()):ListView(
        padding:const EdgeInsets.fromLTRB(16,8,16,90),children:[_calendario(s),_jornada(s)]));
  }
}
