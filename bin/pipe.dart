// Demonstrates using named pipes from Dart. To run this example, open two
// separate command windows. In the first, run:
//   dart examples\pipe.dart server
//
// In the second, run:
//   dart examples\pipe.dart client
//
// The first window will connect to a pipe and then block until a client pipe is
// activated. When the client is opened, it will receive the message from the
// server pipe and then both will exit.
//
// Example based on the following blog post:
//   https://peter.bloomfield.online/introduction-to-win32-named-pipes-cpp/

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const pipeName = r'\\.\pipe\ziti-edge-tunnel-event.sock'; //r'\\.\pipe\dart_pipe';
const pipeMessage = '{"Action":"Normal","Op":"Start"}\n';

LPSTR wsalloc2(int wChars) => calloc<UCHAR>(wChars).cast();

/// A named pipe client
class ClientCommand extends Command<void> {
  @override
  String get name => 'client';
  @override
  String get description => 'Execute the named pipe client.';

  @override
  void run() async {
    final lpPipeName = pipeName.toNativeUtf16();
    final lpBuffer = wsalloc2(16384);
    final lpNumBytesRead = calloc<DWORD>();
    final lpPipeMessage = pipeMessage.toNativeUtf8();
    final lpNumBytesWritten = calloc<DWORD>();
    try {
      stdout.writeln('Connecting to pipe...');
      var pipe = CreateFile(
          lpPipeName,
          GENERIC_ACCESS_RIGHTS.GENERIC_READ | GENERIC_ACCESS_RIGHTS.GENERIC_WRITE,
          FILE_SHARE_MODE.FILE_SHARE_READ | FILE_SHARE_MODE.FILE_SHARE_WRITE,
          nullptr,
          FILE_CREATION_DISPOSITION.OPEN_EXISTING,
          FILE_FLAGS_AND_ATTRIBUTES.FILE_ATTRIBUTE_NORMAL,
          NULL);
      if (pipe == INVALID_HANDLE_VALUE) {
        stderr.writeln('Failed to connect to pipe.');
        exit(1);
      }

      // final result2 = WriteFile(pipe, lpPipeMessage.cast(), pipeMessage.length,
      //     lpNumBytesWritten, nullptr);

      // if (result2 == NULL) {
      //   stderr.writeln('Failed to send data.');
      // } else {
      //   final numBytesWritten = lpNumBytesWritten.value;
      //   stdout.writeln('Number of bytes sent: $numBytesWritten');
      // }

      // stdout.writeln('Reading data from pipe...');
      // final result =
      //     ReadFile(pipe, lpBuffer.cast(), 16384, lpNumBytesRead, nullptr);
      // if (result == NULL) {
      //   stderr.writeln('Failed to read data from the pipe.');
      // } else {
      //   final numBytesRead = lpNumBytesRead.value;
      //   stdout
      //     ..writeln('Number of bytes read: $numBytesRead')
      //     ..writeln('Message: ${lpBuffer.toDartString()}');
      // }
      final receivePort = ReceivePort();
      receivePort.listen((message) {
        stdout.writeln('xxxxxxxxxx: $message');
      });
      await Isolate.spawn(readEvent, (sendPort: receivePort.sendPort, pipe: pipe));
      // stdout.writeln('Done222.');
      // CloseHandle(pipe);
      // stdout.writeln('Done.');
    } finally {
      free(lpPipeName);
      free(lpBuffer);
      free(lpNumBytesRead);
    }
  }
}

void readEvent(({ SendPort sendPort, int pipe }) record) {
  var i = 1;
  while(true) {
    if (i++ >= 10) {
      return;
    }
    final lpBuffer = wsalloc2(16384);
    final lpNumBytesRead = calloc<DWORD>();
    try {
      stdout.writeln('Reading data from pipe...${record.pipe}');
      final result =
          ReadFile(record.pipe, lpBuffer.cast(), 16384, lpNumBytesRead, nullptr);
      if (result == NULL) {
        stderr.writeln('Failed to read data from the pipe.');
      } else {
        final numBytesRead = lpNumBytesRead.value;
        stdout
          ..writeln('Number of bytes read: $numBytesRead')
          ..writeln('Message: ${lpBuffer.toDartString()}');
        record.sendPort.send(lpBuffer.toDartString());
      }
      
    } finally {
      free(lpBuffer);
      free(lpNumBytesRead);
    }
  }
}

/// A named pipe server.
class ServerCommand extends Command<void> {
  @override
  String get name => 'server';
  @override
  String get description => 'Execute the named pipe server.';

  @override
  void run() {
    final lpPipeName = pipeName.toNativeUtf16();
    final lpPipeMessage = pipeMessage.toNativeUtf16();
    final lpNumBytesWritten = calloc<DWORD>();
    try {
      final pipe = CreateNamedPipe(
          lpPipeName,
          FILE_FLAGS_AND_ATTRIBUTES.PIPE_ACCESS_OUTBOUND,
          NAMED_PIPE_MODE.PIPE_TYPE_BYTE,
          1,
          0,
          0,
          0,
          nullptr);
      if (pipe == NULL || pipe == INVALID_HANDLE_VALUE) {
        stderr.writeln('Failed to create outbound pipe instance.');
        exit(1);
      }

      stdout.writeln('Sending data to pipe...');
      var result = ConnectNamedPipe(pipe, nullptr);
      if (result == NULL) {
        CloseHandle(pipe);
        stderr.writeln('Failed to make connection on named pipe.');
        exit(1);
      }

      result = WriteFile(pipe, lpPipeMessage.cast(), pipeMessage.length * 2,
          lpNumBytesWritten, nullptr);
      if (result == NULL) {
        stderr.writeln('Failed to send data.');
      } else {
        final numBytesWritten = lpNumBytesWritten.value;
        stdout.writeln('Number of bytes sent: $numBytesWritten');
      }
      CloseHandle(pipe);
      stdout.writeln('Done.');
    } finally {
      free(lpPipeName);
      free(lpPipeMessage);
      free(lpNumBytesWritten);
    }
  }
}

void main(List<String> args) async {
  final command =
      CommandRunner<void>('pipe', 'A demonstration of Win32 named pipes.')
        ..addCommand(ClientCommand())
        ..addCommand(ServerCommand());

  await command.run(args);
}
