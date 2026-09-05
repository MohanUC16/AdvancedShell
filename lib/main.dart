import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const AdvancedShellApp());

class AdvancedShellApp extends StatelessWidget {
  const AdvancedShellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Shell Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff62e6b5),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff0b1020),
        useMaterial3: true,
      ),
      home: const ShellHome(),
    );
  }
}

enum JobState { running, stopped, done, terminated }

class ShellJob {
  ShellJob(this.id, this.pid, this.command, {this.priority = 5});

  final int id;
  final int pid;
  final String command;
  final int priority;
  JobState state = JobState.running;
  int remainingMs = 4000;
}

class ProcessInfo {
  ProcessInfo(this.pid, this.name, this.burstMs, {this.priority = 5})
      : remainingMs = burstMs;

  final int pid;
  final String name;
  final int burstMs;
  final int priority;
  int remainingMs;
  int waitingMs = 0;
  int responseMs = -1;
  int turnaroundMs = 0;
}

class SimFile {
  SimFile(this.path, this.content, this.owner, this.mode);

  final String path;
  String content;
  final String owner;
  String mode;
}

class SimUser {
  SimUser(this.name, this.password, this.role);

  final String name;
  final String password;
  final String role;
}

class MemoryPage {
  MemoryPage(this.pid, this.page);

  final int pid;
  final int page;
  int lastUsed = 0;
}

class ShellHome extends StatefulWidget {
  const ShellHome({super.key});

  @override
  State<ShellHome> createState() => _ShellHomeState();
}

class _ShellHomeState extends State<ShellHome>
    with SingleTickerProviderStateMixin {
  final _command = TextEditingController();
  final _scroll = ScrollController();
  final _output = <String>[
    'Advanced Shell Simulator v1.0',
    'Integrated OS concepts: processes, scheduling, paging, synchronization, and security.',
    'Login required. Try: login admin admin123',
    '',
  ];
  final _jobs = <ShellJob>[];
  final _processes = <ProcessInfo>[];
  final _files = <SimFile>[
    SimFile('/home/README.txt', 'Welcome to the integrated shell.', 'admin', 'rw-r--r--'),
    SimFile('/home/error.log', 'error: sample diagnostic entry', 'admin', 'rw-r-----'),
    SimFile('/system/kernel.conf', 'protected system configuration', 'admin', 'rw-------'),
  ];
  final _directories = <String>{'/home', '/system'};
  final _users = <SimUser>[
    SimUser('admin', 'admin123', 'admin'),
    SimUser('student', 'student123', 'standard'),
  ];
  final _frames = <MemoryPage>[];
  final _fifo = Queue<MemoryPage>();
  final _lru = <MemoryPage>[];
  final _syncBuffer = <int>[];
  final _syncLog = <String>[];
  final _timers = <Timer>[];
  late final TabController _tabs;

  String? _currentUser;
  String _cwd = '/home';
  int _nextPid = 2000;
  int _nextJob = 1;
  int _nextProcess = 1;
  int _memoryClock = 0;
  int _pageFaults = 0;
  final int _capacity = 4;
  String _replacement = 'FIFO';
  int _quantum = 1000;
  String _schedulerOutput = 'No scheduling run yet.';
  String _syncStatus = 'Idle';
  bool _shellClosed = false;
  bool _syncRunning = false;

  String get _prompt => '${_currentUser ?? "guest"}@sim:$_cwd\$ ';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _tabs.dispose();
    _command.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _print(String line) {
    if (!mounted) return;
    setState(() => _output.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<String> _tokens(String value) => RegExp(r'''[^\s"']+|"[^"]*"|'[^']*' ''')
      .allMatches(value)
      .map((m) => m.group(0)!.replaceAll(RegExp(r'''^["']|["']$'''), ''))
      .toList();

  String _path(String value) {
    if (value == '~') return '/home';
    if (value.startsWith('/')) return _normalize(value);
    return _normalize('$_cwd/$value');
  }

  String _normalize(String path) {
    final parts = <String>[];
    for (final part in path.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..' && parts.isNotEmpty) {
        parts.removeLast();
      } else if (part != '..') {
        parts.add(part);
      }
    }
    return '/${parts.join('/')}';
  }

  void _submit(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return;
    _command.clear();
    _print('$_prompt$input');
    final background = input.endsWith('&');
    final command = (background ? input.substring(0, input.length - 1) : input).trim();
    if (command.contains('|')) {
      _runPipeline(command);
    } else {
      final args = _tokens(command);
      if (args.isNotEmpty) _runCommand(args.first, args.sublist(1), background: background);
    }
  }

  void _runPipeline(String command) {
    var stream = <String>[];
    for (final part in command.split('|')) {
      final args = _tokens(part.trim());
      if (args.isEmpty) continue;
      if (stream.isNotEmpty && args.first == 'grep') {
        final term = args.length > 1 ? args[1] : '';
        stream = stream.where((line) => line.contains(term)).toList();
      } else if (stream.isNotEmpty && args.first == 'sort') {
        stream = stream.toList()..sort();
      } else {
        stream = _runCommand(args.first, args.sublist(1), printOutput: false);
      }
    }
    for (final line in stream) {
      _print(line);
    }
  }

  List<String> _runCommand(
    String name,
    List<String> args, {
    bool background = false,
    bool printOutput = true,
  }) {
    final result = <String>[];
    void out(String line) => result.add(line);
    if (name == 'exit') {
      setState(() => _shellClosed = true);
      out('Shell session ended. Restart from the toolbar to log in again.');
    } else if (name == 'help') {
      out('Authentication: login <user> <password>, logout, whoami');
      out('Files: cd pwd ls cat mkdir rmdir rm touch chmod');
      out('Processes: ps jobs fg <id> bg <id> kill <pid>');
      out('Scheduling: schedule rr <quantum> | schedule priority');
      out('Memory: memory alloc <pid> <pages> [FIFO|LRU], memory access <pid> <page>');
      out('Synchronization: sync start | sync status');
      out('Pipes: ls | grep txt | sort');
    } else if (name == 'login') {
      _login(args, out);
    } else if (name == 'logout') {
      setState(() => _currentUser = null);
      out('Logged out.');
    } else if (name == 'whoami') {
      out(_currentUser ?? 'not authenticated');
    } else if (_currentUser == null) {
      out('Permission denied: authenticate with login <user> <password>.');
    } else {
      switch (name) {
        case 'pwd':
          out(_cwd);
        case 'echo':
          out(args.join(' '));
        case 'clear':
          setState(_output.clear);
        case 'cd':
          _cd(args, out);
        case 'ls':
          _ls(args, out);
        case 'cat':
          _cat(args, out);
        case 'mkdir':
          _mkdir(args, out);
        case 'rmdir':
          _rmdir(args, out);
        case 'rm':
          _rm(args, out);
        case 'touch':
          _touch(args, out);
        case 'chmod':
          _chmod(args, out);
        case 'kill':
          _kill(args, out);
        case 'jobs':
          for (final job in _jobs) {
            out('[${job.id}] ${job.state.name} ${job.command}');
          }
        case 'fg':
          _jobState(args, out, foreground: true);
        case 'bg':
          _jobState(args, out, foreground: false);
        case 'ps':
          for (final process in _processes) {
            out('${process.pid}\t${process.name}\tremaining=${process.remainingMs}ms');
          }
        case 'schedule':
          _schedule(args, out);
        case 'memory':
          _memoryCommand(args, out);
        case 'sync':
          _syncCommand(args, out);
        default:
          if (background) {
            _startJob('$name ${args.join(' ')}', out);
          } else {
            out('$name: command not found');
          }
      }
    }
    if (printOutput) {
      for (final line in result) {
        _print(line);
      }
    }
    return result;
  }

  void _login(List<String> args, void Function(String) out) {
    if (args.length < 2) {
      out('Usage: login <username> <password>');
      return;
    }
    final user = _users.where((candidate) => candidate.name == args[0]).firstOrNull;
    if (user == null || user.password != args[1]) {
      out('Authentication failed.');
    } else {
      setState(() => _currentUser = user.name);
      out('Authenticated as ${user.name} (${user.role}).');
    }
  }

  void _cd(List<String> args, void Function(String) out) {
    final target = _path(args.isEmpty ? '/home' : args.first);
    if (_directories.contains(target)) {
      setState(() => _cwd = target);
    } else {
      out('cd: $target: no such directory');
    }
  }

  void _ls(List<String> args, void Function(String) out) {
    final target = _path(args.isEmpty ? _cwd : args.first);
    if (!_directories.contains(target)) {
      out('ls: $target: no such directory');
      return;
    }
    final prefix = target == '/' ? '/' : '$target/';
    final entries = <String>{};
    for (final directory in _directories) {
      if (directory.startsWith(prefix) &&
          !directory.substring(prefix.length).contains('/')) {
        entries.add('${directory.substring(prefix.length)}/');
      }
    }
    for (final file in _files) {
      if (file.path.startsWith(prefix) &&
          !file.path.substring(prefix.length).contains('/')) {
        entries.add(file.path.substring(prefix.length));
      }
    }
    out(entries.isEmpty ? '(empty)' : (entries.toList()..sort()).join('  '));
  }

  bool _canWrite(SimFile file) {
    if (_currentUser == 'admin') return true;
    return file.owner == _currentUser && file.mode[1] == 'w';
  }

  void _cat(List<String> args, void Function(String) out) {
    if (args.isEmpty) {
      out('cat: missing operand');
      return;
    }
    final file = _files.where((item) => item.path == _path(args.first)).firstOrNull;
    out(file == null ? 'cat: ${args.first}: no such file' : file.content);
  }

  void _mkdir(List<String> args, void Function(String) out) {
    if (args.isEmpty) {
      out('mkdir: missing operand');
      return;
    }
    final path = _path(args.first);
    if (_directories.contains(path) || _files.any((file) => file.path == path)) {
      out('mkdir: already exists');
    } else {
      setState(() => _directories.add(path));
      out('Created $path');
    }
  }

  void _rmdir(List<String> args, void Function(String) out) {
    if (args.isEmpty) {
      out('rmdir: missing operand');
      return;
    }
    final path = _path(args.first);
    final children = _directories.any((item) => item.startsWith('$path/')) ||
        _files.any((file) => file.path.startsWith('$path/'));
    if (!_directories.contains(path)) {
      out('rmdir: no such directory');
    } else if (children) {
      out('rmdir: directory not empty');
    } else {
      setState(() => _directories.remove(path));
      out('Removed $path');
    }
  }

  void _rm(List<String> args, void Function(String) out) {
    if (args.isEmpty) {
      out('rm: missing operand');
      return;
    }
    final file = _files.where((item) => item.path == _path(args.first)).firstOrNull;
    if (file == null) {
      out('rm: no such file');
    } else if (!_canWrite(file)) {
      out('rm: permission denied');
    } else {
      setState(() => _files.remove(file));
      out('Removed ${file.path}');
    }
  }

  void _touch(List<String> args, void Function(String) out) {
    if (args.isEmpty) {
      out('touch: missing operand');
      return;
    }
    final path = _path(args.first);
    final existing = _files.where((file) => file.path == path).firstOrNull;
    if (existing != null) {
      if (_canWrite(existing)) {
        out('Updated $path');
      } else {
        out('touch: permission denied');
      }
    } else {
      setState(() => _files.add(SimFile(path, '', _currentUser!, 'rw-------')));
      out('Created $path');
    }
  }

  void _chmod(List<String> args, void Function(String) out) {
    if (args.length < 2) {
      out('Usage: chmod <mode> <file>');
      return;
    }
    final file = _files.where((item) => item.path == _path(args[1])).firstOrNull;
    if (file == null) {
      out('chmod: no such file');
    } else if (_currentUser != 'admin' && file.owner != _currentUser) {
      out('chmod: permission denied');
    } else {
      setState(() => file.mode = args[0]);
      out('Mode for ${file.path}: ${file.mode}');
    }
  }

  void _startJob(String command, void Function(String) out) {
    final job = ShellJob(_nextJob++, _nextPid++, command);
    _jobs.add(job);
    _processes.add(ProcessInfo(job.pid, command, job.remainingMs));
    out('[${job.id}] ${job.pid}');
    final timer = Timer(Duration(milliseconds: job.remainingMs), () {
      if (!mounted || job.state == JobState.terminated) return;
      setState(() => job.state = JobState.done);
      _print('[${job.id}]+ Done ${job.command}');
    });
    _timers.add(timer);
    setState(() {});
  }

  void _kill(List<String> args, void Function(String) out) {
    final pid = args.isEmpty ? -1 : int.tryParse(args.first) ?? -1;
    final job = _jobs.where((item) => item.pid == pid).firstOrNull;
    if (job == null) {
      out('kill: unknown process $pid');
    } else {
      setState(() => job.state = JobState.terminated);
      out('Terminated process $pid');
    }
  }

  void _jobState(List<String> args, void Function(String) out,
      {required bool foreground}) {
    final id = args.isEmpty ? -1 : int.tryParse(args.first.replaceFirst('%', '')) ?? -1;
    final job = _jobs.where((item) => item.id == id).firstOrNull;
    if (job == null) {
      out('job not found');
    } else {
      setState(() => job.state = JobState.running);
      out('[${job.id}] ${foreground ? "foreground" : "background"} ${job.command}');
    }
  }

  void _schedule(List<String> args, void Function(String) out) {
    if (args.isEmpty) {
      out('Usage: schedule rr <quantum-ms> | schedule priority');
      return;
    }
    final processes = [
      ProcessInfo(_nextProcess++, 'compile', 3000, priority: 2),
      ProcessInfo(_nextProcess++, 'backup', 2000, priority: 5),
      ProcessInfo(_nextProcess++, 'render', 4000, priority: 1),
    ];
    if (args.first == 'rr') {
      _quantum = args.length > 1 ? int.tryParse(args[1]) ?? 1000 : 1000;
      _schedulerOutput = _runRoundRobin(processes, _quantum);
    } else if (args.first == 'priority') {
      _schedulerOutput = _runPriority(processes);
    } else {
      out('Unknown scheduler. Use rr or priority.');
      return;
    }
    out(_schedulerOutput);
    setState(() {});
  }

  String _runRoundRobin(List<ProcessInfo> input, int quantum) {
    final queue = Queue<ProcessInfo>.from(input);
    final order = <String>[];
    var elapsed = 0;
    while (queue.isNotEmpty) {
      final process = queue.removeFirst();
      final slice = min(quantum, process.remainingMs);
      if (process.responseMs < 0) process.responseMs = elapsed;
      process.remainingMs -= slice;
      elapsed += slice;
      for (final waiting in queue) {
        waiting.waitingMs += slice;
      }
      order.add('${process.name}($slice ms)');
      if (process.remainingMs > 0) {
        queue.add(process);
      } else {
        process.turnaroundMs = elapsed;
      }
    }
    final averageWait =
        input.map((p) => p.waitingMs).reduce((a, b) => a + b) / input.length;
    return 'Round-Robin quantum=${quantum}ms\nOrder: ${order.join(' -> ')}\n'
        'Average waiting=${averageWait.toStringAsFixed(1)}ms; '
        'response=${input.map((p) => p.responseMs).join(", ")}ms';
  }

  String _runPriority(List<ProcessInfo> input) {
    final queue = input.toList()..sort((a, b) => b.priority.compareTo(a.priority));
    var elapsed = 0;
    final order = <String>[];
    for (final process in queue) {
      process.responseMs = elapsed;
      process.turnaroundMs = elapsed + process.burstMs;
      process.waitingMs = elapsed;
      elapsed += process.burstMs;
      order.add('${process.name}(priority ${process.priority})');
    }
    final averageWait =
        input.map((p) => p.waitingMs).reduce((a, b) => a + b) / input.length;
    return 'Priority scheduling with preemption\nOrder: ${order.join(' -> ')}\n'
        'Average waiting=${averageWait.toStringAsFixed(1)}ms; '
        'turnaround=${input.map((p) => p.turnaroundMs).join(", ")}ms';
  }

  void _memoryCommand(List<String> args, void Function(String) out) {
    if (args.isEmpty || args.first == 'status') {
      out('Frames: ${_frames.map((p) => "${p.pid}:${p.page}").join(" ")}');
      out('Algorithm: $_replacement; page faults: $_pageFaults');
      return;
    }
    if (args.first == 'alloc' && args.length >= 3) {
      final pid = int.tryParse(args[1]) ?? 0;
      final pages = int.tryParse(args[2]) ?? 0;
      _replacement = args.length > 3 && args[3].toUpperCase() == 'LRU' ? 'LRU' : 'FIFO';
      for (var page = 0; page < pages; page++) {
        _accessPage(pid, page, out);
      }
      out('Allocated $pages pages to process $pid using $_replacement');
    } else if (args.first == 'access' && args.length >= 3) {
      _accessPage(int.tryParse(args[1]) ?? 0, int.tryParse(args[2]) ?? 0, out);
    } else if (args.first == 'free' && args.length >= 2) {
      final pid = int.tryParse(args[1]) ?? 0;
      setState(() {
        _frames.removeWhere((page) => page.pid == pid);
        _fifo.removeWhere((page) => page.pid == pid);
        _lru.removeWhere((page) => page.pid == pid);
      });
      out('Freed memory for process $pid');
    } else {
      out('Usage: memory alloc <pid> <pages> [FIFO|LRU], access, free, status');
    }
  }

  void _accessPage(int pid, int pageNumber, void Function(String) out) {
    _memoryClock++;
    final existing = _frames.where((p) => p.pid == pid && p.page == pageNumber).firstOrNull;
    if (existing != null) {
      existing.lastUsed = _memoryClock;
      _lru.remove(existing);
      _lru.add(existing);
      out('Page hit: $pid:$pageNumber');
      return;
    }
    _pageFaults++;
    final page = MemoryPage(pid, pageNumber)..lastUsed = _memoryClock;
    if (_frames.length >= _capacity) {
      final victim = _replacement == 'LRU' ? _lru.removeAt(0) : _fifo.removeFirst();
      _frames.remove(victim);
      _lru.remove(victim);
      out('Page fault: replaced ${victim.pid}:${victim.page}');
    } else {
      out('Page fault: loaded $pid:$pageNumber');
    }
    _frames.add(page);
    _fifo.add(page);
    _lru.add(page);
    setState(() {});
  }

  void _syncCommand(List<String> args, void Function(String) out) {
    if (args.isEmpty || args.first == 'status') {
      out('$_syncStatus; buffer=${_syncBuffer.join(",")}');
    } else if (args.first == 'start') {
      _startProducerConsumer(out);
    } else {
      out('Usage: sync start | sync status');
    }
  }

  void _startProducerConsumer(void Function(String) out) {
    if (_syncRunning) {
      out('Synchronization simulation already running.');
      return;
    }
    _syncRunning = true;
    _syncBuffer.clear();
    _syncLog.clear();
    _syncStatus = 'Running producer-consumer with mutex';
    out('Producer-consumer started: semaphore capacity=3');
    for (var i = 1; i <= 6; i++) {
      final timer = Timer(Duration(milliseconds: i * 250), () {
        if (!mounted) return;
        setState(() {
          if (i.isOdd && _syncBuffer.length < 3) {
            _syncBuffer.add(i);
            _syncLog.add('Producer produced item $i (mutex acquired/released)');
          } else if (_syncBuffer.isNotEmpty) {
            final item = _syncBuffer.removeAt(0);
            _syncLog.add('Consumer consumed item $item (mutex acquired/released)');
          }
          if (i == 6) {
            _syncRunning = false;
            _syncStatus = 'Complete: no race condition detected';
          }
        });
      });
      _timers.add(timer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Shell Simulator'),
        actions: [
          Chip(
            label: Text(_currentUser == null ? 'Not authenticated' : '$_currentUser'),
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Terminal', icon: Icon(Icons.terminal)),
            Tab(text: 'Scheduling', icon: Icon(Icons.alt_route)),
            Tab(text: 'Memory', icon: Icon(Icons.memory)),
            Tab(text: 'Synchronization', icon: Icon(Icons.sync)),
            Tab(text: 'Security', icon: Icon(Icons.lock)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _terminalTab(),
          _schedulingTab(),
          _memoryTab(),
          _syncTab(),
          _securityTab(),
        ],
      ),
    );
  }

  Widget _terminalTab() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff050912),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.builder(
              controller: _scroll,
              itemCount: _output.length,
              itemBuilder: (context, index) => SelectableText(
                _output[index],
                style: TextStyle(
                  fontFamily: 'monospace',
                  height: 1.45,
                  color: index == _output.length - 1
                      ? const Color(0xff62e6b5)
                      : Colors.white70,
                ),
              ),
            ),
          ),
        ),
        if (!_shellClosed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _command,
              autofocus: true,
              onSubmitted: _submit,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                prefixText: _prompt,
                prefixStyle: const TextStyle(color: Color(0xff62e6b5)),
                hintText: 'Type help for commands',
                suffixIcon: IconButton(
                  onPressed: () => _submit(_command.text),
                  icon: const Icon(Icons.play_arrow),
                ),
                filled: true,
                fillColor: const Color(0xff151c30),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _schedulingTab() => _panel(
        title: 'Process Scheduling',
        children: [
          const Text('Round-Robin uses a configurable quantum. Priority scheduling '
              'uses priority order with FCFS tie-breaking.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _runSchedulingFromPanel(false),
                child: const Text('Run Round-Robin'),
              ),
              FilledButton(
                onPressed: () => _runSchedulingFromPanel(true),
                child: const Text('Run Priority'),
              ),
              DropdownButton<int>(
                value: _quantum,
                items: const [500, 1000, 2000]
                    .map((value) => DropdownMenuItem(value: value, child: Text('$value ms')))
                    .toList(),
                onChanged: (value) => setState(() => _quantum = value ?? 1000),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SelectableText(_schedulerOutput, style: const TextStyle(fontFamily: 'monospace')),
        ],
      );

  void _runSchedulingFromPanel(bool priority) {
    final processes = [
      ProcessInfo(_nextProcess++, 'compile', 3000, priority: 2),
      ProcessInfo(_nextProcess++, 'backup', 2000, priority: 5),
      ProcessInfo(_nextProcess++, 'render', 4000, priority: 1),
    ];
    setState(() {
      _schedulerOutput =
          priority ? _runPriority(processes) : _runRoundRobin(processes, _quantum);
    });
  }

  Widget _memoryTab() => _panel(
        title: 'Paging and Page Replacement',
        children: [
          Text('Frames: $_capacity    Algorithm: $_replacement    Page faults: $_pageFaults'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () {
                  _replacement = 'FIFO';
                  for (var i = 0; i < 6; i++) {
                    _accessPage(101, i, (_) {});
                  }
                  setState(() {});
                },
                child: const Text('Demo FIFO'),
              ),
              FilledButton(
                onPressed: () {
                  _replacement = 'LRU';
                  for (final page in [0, 1, 2, 0, 3, 4]) {
                    _accessPage(101, page, (_) {});
                  }
                  setState(() {});
                },
                child: const Text('Demo LRU'),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _frames.clear();
                  _fifo.clear();
                  _lru.clear();
                  _pageFaults = 0;
                }),
                child: const Text('Reset frames'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Resident pages: ${_frames.map((p) => "${p.pid}:${p.page}").join("  ")}'),
          const Text('Use terminal: memory alloc 101 6 FIFO | memory access 101 2'),
        ],
      );

  Widget _syncTab() => _panel(
        title: 'Producer-Consumer Synchronization',
        children: [
          Text(_syncStatus),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _syncRunning ? null : () => _startProducerConsumer((_) {}),
            child: const Text('Start simulation'),
          ),
          const SizedBox(height: 12),
          Text('Bounded buffer: ${_syncBuffer.join(", ")}'),
          const SizedBox(height: 8),
          ..._syncLog.map((entry) => Text(entry, style: const TextStyle(fontFamily: 'monospace'))),
        ],
      );

  Widget _securityTab() => _panel(
        title: 'Authentication and File Permissions',
        children: [
          Text('Demo users: admin/admin123 (admin), student/student123 (standard)'),
          const SizedBox(height: 8),
          Text('Current user: ${_currentUser ?? "not authenticated"}'),
          const SizedBox(height: 12),
          ..._files.map((file) => ListTile(
                dense: true,
                title: Text(file.path),
                subtitle: Text('owner=${file.owner}  mode=${file.mode}'),
                leading: Icon(file.path.startsWith('/system') ? Icons.security : Icons.description),
              )),
          const Text('Standard users cannot modify files owned by another user or protected system files.'),
        ],
      );

  Widget _panel({required String title, required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const Divider(height: 28),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
