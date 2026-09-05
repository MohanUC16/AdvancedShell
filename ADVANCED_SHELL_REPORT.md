# Advanced Shell Simulation with Integrated OS Concepts

**Student:** Kolla Mohan Chaitanya  
**UC ID:** 005061481  
**Implementation:** Dart and Flutter

## Overview

This project implements a custom Unix-like shell simulator as a Flutter
application. The shell internally models process management, scheduling,
memory management, synchronization, piping, authentication, and file
permissions. All state is kept in memory so the simulator is safe to run and
demonstrate on any supported Flutter platform.

The user interface is divided into Terminal, Scheduling, Memory,
Synchronization, and Security tabs. The terminal accepts commands, while the
other tabs expose the internal state and demonstrations required by the four
deliverables.

## Deliverable 1: Shell and Process Management

The shell parser separates commands from arguments, supports quoted arguments,
and recognizes a trailing ampersand for background execution. The built-in
commands include `cd`, `pwd`, `exit`, `echo`, `clear`, `ls`, `cat`, `mkdir`,
`rmdir`, `rm`, `touch`, `chmod`, `kill`, `ps`, `jobs`, `fg`, and `bg`.

The filesystem is represented by directory and file collections. Each file has
an owner and a permission mode. A background command receives a synthetic
process ID and job ID. A timer simulates completion, and the job table reports
running, done, or terminated states. Foreground and background commands
therefore demonstrate shell job control without creating real operating-system
processes.

Invalid commands, missing arguments, unknown files, invalid paths, unknown
jobs, and unauthorized operations produce explicit terminal messages.

## Deliverable 2: Process Scheduling

The Round-Robin scheduler stores processes in a queue. Each process receives a
configurable time quantum. If its remaining burst is longer than the quantum,
the process is placed at the back of the queue; otherwise it is removed. The
implementation records the execution order, waiting time, response time, and
turnaround time.

The priority scheduler orders processes by descending priority. Equal-priority
processes retain their insertion order, providing FCFS tie handling. The
selected process completes before the next process is selected, and the output
shows the resulting priority order. The scheduling tab and terminal both
provide demonstrations and performance metrics.

## Deliverable 3: Memory Management and Synchronization

The paging simulation uses four fixed-size frames. A page is identified by a
process ID and page number. When a requested page is absent, a page fault is
recorded. If memory is full, FIFO removes the page loaded earliest, while LRU
removes the page with the oldest access timestamp. Resident pages, selected
algorithm, and total page faults are visible in the Memory tab.

The synchronization demonstration implements a bounded producer-consumer
buffer with capacity three. Producers add items only when space exists and
consumers remove items only when an item exists. Each operation records mutex
acquisition and release in the event log. This models semaphore-style
coordination and prevents simultaneous unsafe access to the shared buffer.

## Deliverable 4: Integration, Piping, and Security

Pipes are processed as an in-memory stream. The output of the first command is
passed to the next command, allowing examples such as `ls | grep txt | sort`.
The pipe implementation demonstrates the same producer-consumer idea used by
operating systems to connect process input and output.

The login system includes administrator and standard users. Authentication is
required before protected shell commands can run. Files contain owners and
permission modes. Administrators can modify all files, while standard users
cannot modify files owned by another user or protected system files. The
Security tab displays the current identity and the simulated permission table.

## Challenges and Improvements

The main challenge was integrating several operating-system concepts without
depending on unsafe host system calls. The solution uses explicit state
objects, synthetic process IDs, deterministic timers, and an in-memory
filesystem. Another challenge was exposing complex state clearly; separate
tabs and terminal commands provide both visual and command-driven access.

Future improvements could include a real priority queue, configurable memory
frame counts, detailed Gantt charts, deadlock detection, persistent users,
command history, and a richer permission model with execute checks.

## Conclusion

The completed application provides a single integrated environment for all
four deliverables. It demonstrates shell commands and job control, configurable
scheduling algorithms and metrics, paging with FIFO/LRU replacement,
producer-consumer synchronization, piping, authentication, and permissions.
