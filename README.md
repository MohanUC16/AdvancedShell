# Advanced Shell Simulator

A standalone Flutter implementation of the **Advanced Shell Simulation with
Integrated OS Concepts** project. This project is built from scratch and
implements all four deliverables in one safe, in-memory simulation. It never
executes commands or modifies files on the host computer.

## Requirements

- Flutter 3.x
- Dart 3.x
- macOS, Windows, Linux, Android, iOS, or a supported web browser

## Run

```bash
flutter pub get
flutter run
```

For macOS:

```bash
flutter run -d macos
```

## Features

### Deliverable 1: Shell and Process Management

- Authentication-aware terminal interface
- `cd`, `pwd`, `exit`, `echo`, `clear`, `ls`, `cat`, `mkdir`, `rmdir`
- `rm`, `touch`, `chmod`, `kill`, `ps`, `jobs`, `fg`, and `bg`
- Foreground/background jobs with synthetic process IDs
- In-memory filesystem and explicit error messages

### Deliverable 2: Scheduling

- Round-Robin scheduling with configurable quantum
- Priority scheduling with priority ordering and FCFS tie handling
- Preemption represented by the scheduling order
- Waiting, turnaround, and response-time calculations

Terminal examples:

```text
login admin admin123
schedule rr 500
schedule priority
```

### Deliverable 3: Memory and Synchronization

- Fixed-size page frames
- FIFO and LRU page replacement
- Page-fault counting and resident-page tracking
- Producer-consumer bounded buffer
- Mutex/semaphore behavior represented in the synchronization log

Terminal examples:

```text
memory alloc 101 6 FIFO
memory access 101 2
memory status
sync start
```

### Deliverable 4: Integration and Security

- Pipe chains such as `ls | grep txt | sort`
- User authentication with admin and standard roles
- File ownership and read/write mode checks
- Protected system files for standard users
- Dedicated panels for each OS concept

Demo credentials:

| Username | Password | Role |
| --- | --- | --- |
| `admin` | `admin123` | Administrator |
| `student` | `student123` | Standard user |

## Project files

- `lib/main.dart` - complete integrated simulator
- `test/widget_test.dart` - Flutter widget coverage
- `ADVANCED_SHELL_REPORT.md` - report covering all deliverables

## Validation

```bash
flutter analyze
flutter test
```
