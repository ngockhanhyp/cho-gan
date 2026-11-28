part of 'cloud_app.dart';

class OwnerConsole extends StatefulWidget {
  const OwnerConsole({super.key});
  @override
  State<OwnerConsole> createState() => _OwnerConsoleState();
}

class _OwnerConsoleState extends State<OwnerConsole> {
  String section = 'Tin đăng', query = '', reason = '';
  String? thread;
  int page = 0;
  late Future<List<dynamic>> rows;
  String? get uid => db.auth.currentUser?.id;
  late final StreamSubscription<AuthState> auth;

  Future<List<dynamic>> fetch() async {
    if (uid == null) return [];
    return List.from(await db.rpc('owner_console', params: {
      'section': section, 'page_no': page, 'target': thread,
      'reason': reason, 'search_term': query,
    }));
  }

  void refresh() => setState(() => rows = fetch());
  void select(String value) {
    section = value;
    page = 0;
    query = '';
    if (value != 'Tin nhắn') { thread = null; reason = ''; }
    refresh();
  }

  @override
  void initState() {
    super.initState();
    rows = fetch();
    var previous = uid;
    auth = db.auth.onAuthStateChange.listen((_) {
      if (mounted && previous != uid) {
        previous = uid;
        select('Tin đăng');
      }
    });
  }

  @override
  void dispose() { auth.cancel(); super.dispose(); }

  Future<void> perform(String id, String action) async {
    var input = '';
    final result = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: Text('Lý do · $action'),
      content: TextField(maxLength: 300, autofocus: true, onChanged: (v) => input = v.trim()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
        FilledButton(onPressed: () {
          if (input.length >= 5) Navigator.pop(c, input);
        }, child: const Text('Xác nhận và ghi nhật ký')),
      ],
    ));
    if (!mounted || result == null) return;
    if (action != 'Đọc hội thoại') {
      try {
        await db.rpc('owner_console', params: {'section': action, 'target': id, 'reason': result});
        if (mounted) refresh();
      } catch (e) {
        if (mounted) notice(context, friendly(e));
      }
      return;
    }
    thread = id;
    reason = result;
    select('Tin nhắn');
  }

  Future<void> manage(Map row, String op) async {
    final id = row['row_id'];
    try {
      final item = op == 'delete_message' ? <String,dynamic>{} :
          Map<String,dynamic>.from(await db.rpc('owner_content_action', params: {'op':'inspect','target':id}));
      if (!mounted) return;
      var title = item['title'] as String? ?? '';
      var description = item['description'] as String? ?? '';
      var price = item['price']?.toString() ?? '';
      var justification = '';
      String? photo;
      final photos = List<String>.from(item['photos'] ?? []);
      final edit = op == 'edit';
      final removePhoto = op == 'remove_photo';
      final action = {'edit':'Sửa nội dung','remove_photo':'Gỡ ảnh khỏi tin','delete_listing':'Xóa tin đăng','delete_message':'Xóa tin nhắn'}[op]!;
      final form = GlobalKey<FormState>();
      final confirmed = await showDialog<bool>(context: context, builder: (dialog) =>
        StatefulBuilder(builder: (dialog, change) => AlertDialog(
          title: Text(action),
          content: SizedBox(width: 500, child: SingleChildScrollView(child: Form(key: form, child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row['label']), SelectableText(id),
              if (op == 'delete_message') Text(row['detail'] ?? ''),
              if (edit) ...[
                TextFormField(initialValue:title, decoration:const InputDecoration(labelText:'Tiêu đề'), maxLength:160,
                  onChanged:(v)=>title=v, validator:(v)=>(v?.trim().length ?? 0)<4?'Nhập ít nhất 4 ký tự':null),
                TextFormField(initialValue:description, decoration:const InputDecoration(labelText:'Nội dung'), maxLines:5,maxLength:4000,
                  onChanged:(v)=>description=v, validator:(v)=>(v?.trim().length ?? 0)<10?'Nhập ít nhất 10 ký tự':null),
                TextFormField(initialValue:price, decoration:const InputDecoration(labelText:'Giá (đ)'),keyboardType:TextInputType.number,
                  onChanged:(v)=>price=v,validator:(v)=>(int.tryParse(v ?? '') ?? -1)<0?'Giá không hợp lệ':null),
              ],
              if (removePhoto) ...[
                if (photos.isEmpty) const Text('Tin này chưa có ảnh.'),
                Wrap(spacing:8,runSpacing:8,children:[
                  for(final path in photos) ChoiceChip(selected:photo==path,
                    label: ListingImage(path:path,size:72), onSelected:(_)=>change(()=>photo=path)),
                ]),
              ],
              if (op.startsWith('delete_')) const Text('Thao tác xóa có hiệu lực ngay khi xác nhận.'),
              TextFormField(decoration:const InputDecoration(labelText:'Lý do xử lý'),maxLength:300,
                onChanged:(v)=>justification=v.trim(),validator:(_)=>justification.length<5?'Nhập ít nhất 5 ký tự':null),
            ],
          )))),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Hủy')),
            FilledButton(onPressed:removePhoto && photo==null?null:(){
              if(form.currentState!.validate()) Navigator.pop(dialog,true);
            },child:Text(action)),
          ],
        )));
      if (confirmed != true || !mounted) return;
      await db.rpc('owner_content_action', params:{
        'op':op,'target':id,'reason':justification,'payload':{
          'version':item['version'], 'thread':thread, 'photo':photo,
          if(edit) ...{'title':title,'description':description,'price':price},
        },
      });
      if(mounted) { refresh(); notice(context,'Đã ghi nhận thao tác'); }
    } catch(e) { if(mounted) notice(context,friendly(e)); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản trị Passy')),
    body: uid == null ? Center(child: FilledButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Login())),
      child: const Text('Đăng nhập quản trị'),
    )) : FutureBuilder<List<dynamic>>(
      future: rows,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: TextButton(
          onPressed: refresh, child: Text('${friendly(snapshot.error!)} · Thử lại'),
        ));
        final entries = snapshot.data ?? [];
        final desktop = MediaQuery.sizeOf(context).width >= 900;
        const sections = {'Tin đăng':Icons.storefront_outlined,'Thành viên':Icons.people_outline,
          'Hội thoại':Icons.forum_outlined,'Nhật ký':Icons.history};
        final content = Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (!desktop) Wrap(spacing: 8, runSpacing: 6, children: [
              ActionChip(
                avatar: const Icon(Icons.flag_outlined),
                label: const Text('Báo cáo'),
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ModerationPage())),
              ),
              for (final name in ['Tin đăng','Thành viên','Hội thoại','Nhật ký'])
                ChoiceChip(label: Text(name), selected: section == name,
                  onSelected: (_) => select(name)),

            ]),
            const SizedBox(height: 18),
            Text(thread == null ? section : 'Nội dung hội thoại', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (thread == null) TextFormField(
              key: ValueKey(section), initialValue: query,
              decoration: const InputDecoration(labelText: 'Tìm kiếm', suffixIcon: Icon(Icons.search)),
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (v) { query = v.trim(); page = 0; refresh(); },
            ),
            if (thread != null) const ListTile(title: Text('Tin nhắn · mới nhất trước')),
            for (final row in entries) ListTile(title: Text(row['label']),
              subtitle: SelectableText(row['detail'] ?? ''),
              trailing: section == 'Tin đăng' ? PopupMenuButton<String>(
                onSelected: (action) {
                  if (['Ẩn tin','Gỡ ẩn'].contains(action)) {
                    perform(row['row_id'], action);
                  } else {
                    manage(row, action);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value:'edit',child: Text('Sửa nội dung và giá')),
                  const PopupMenuItem(value:'remove_photo',child: Text('Gỡ ảnh khỏi tin')),
                  const PopupMenuItem(value:'delete_listing',child: Text('Xóa tin đăng')),
                  for (final name in ['Ẩn tin', 'Gỡ ẩn'])
                    PopupMenuItem(value: name, child: Text(name)),
                ],
              ) : section == 'Tin nhắn' ? IconButton(tooltip:'Xóa tin nhắn',icon:const Icon(Icons.delete_outline),
                onPressed:()=>manage(row,'delete_message')) : section == 'Hội thoại' ? const Icon(Icons.chevron_right) : null,
              onTap: section == 'Hội thoại' ? () => perform(row['row_id'], 'Đọc hội thoại') : null),
            if (entries.isEmpty) const ListTile(title: Text('Chưa có dữ liệu phù hợp')),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(onPressed: page == 0 ? null : () { page--; refresh(); }, icon: const Icon(Icons.chevron_left)),
              Text('Trang ${page+1}'),
              IconButton(onPressed: entries.length < 50 ? null : () { page++; refresh(); }, icon: const Icon(Icons.chevron_right)),
              IconButton(tooltip: 'Tải lại', onPressed: refresh, icon: const Icon(Icons.refresh)),
            ]),
          ]),
        ));
        if (!desktop) return content;
        return Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          SizedBox(width:226, child: Material(color:Theme.of(context).colorScheme.surfaceContainerLow,
            child:ListView(padding:const EdgeInsets.symmetric(vertical:16,horizontal:8),children:[
              for(final entry in sections.entries)
                ListTile(selected:section==entry.key || (entry.key=='Hội thoại' && thread!=null),
                  leading:Icon(entry.value),title:Text(entry.key),onTap:()=>select(entry.key)),
              const Divider(),
              ListTile(leading:const Icon(Icons.flag_outlined),title:const Text('Báo cáo'),
                onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ModerationPage()))),
            ]))),
          const VerticalDivider(width:1),
          Expanded(child:content),
        ]);
      },
    ),
  );
}
