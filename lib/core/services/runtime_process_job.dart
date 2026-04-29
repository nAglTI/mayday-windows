import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

const _jobObjectExtendedLimitInformation = 9;
const _jobObjectLimitKillOnJobClose = 0x00002000;
const _processTerminate = 0x0001;
const _processSetQuota = 0x0100;

class RuntimeProcessJob {
  RuntimeProcessJob();

  _Kernel32Api? _kernel32Api;
  int? _jobHandle;

  _Kernel32Api get _api => _kernel32Api ??= _Kernel32Api();

  void attach(Process process) {
    if (!Platform.isWindows) {
      return;
    }

    final processHandle = _api.openProcess(
      _processTerminate | _processSetQuota,
      inheritHandle: false,
      processId: process.pid,
    );
    if (processHandle == 0) {
      throw StateError(
        'OpenProcess failed for pid ${process.pid}. '
        'Win32 error: ${_api.lastError()}',
      );
    }

    try {
      final jobHandle = _ensureJobHandle();
      if (!_api.assignProcessToJobObject(jobHandle, processHandle)) {
        throw StateError(
          'AssignProcessToJobObject failed for pid ${process.pid}. '
          'Win32 error: ${_api.lastError()}',
        );
      }
    } finally {
      _api.closeHandle(processHandle);
    }
  }

  int _ensureJobHandle() {
    final existingHandle = _jobHandle;
    if (existingHandle != null) {
      return existingHandle;
    }

    final jobHandle = _api.createJobObject();
    if (jobHandle == 0) {
      throw StateError(
        'CreateJobObject failed. Win32 error: ${_api.lastError()}',
      );
    }

    final info = calloc<_JobObjectExtendedLimitInformation>();
    try {
      info.ref.basicLimitInformation.limitFlags = _jobObjectLimitKillOnJobClose;
      final configured = _api.setInformationJobObject(
        jobHandle,
        _jobObjectExtendedLimitInformation,
        info.cast(),
        sizeOf<_JobObjectExtendedLimitInformation>(),
      );
      if (!configured) {
        final error = _api.lastError();
        _api.closeHandle(jobHandle);
        throw StateError(
          'SetInformationJobObject failed. Win32 error: $error',
        );
      }

      _jobHandle = jobHandle;
      return jobHandle;
    } finally {
      calloc.free(info);
    }
  }
}

final class _Kernel32Api {
  _Kernel32Api() : _kernel32 = DynamicLibrary.open('kernel32.dll') {
    _createJobObject = _kernel32.lookupFunction<
        IntPtr Function(Pointer<Void>, Pointer<Utf16>),
        int Function(Pointer<Void>, Pointer<Utf16>)>('CreateJobObjectW');
    _setInformationJobObject = _kernel32.lookupFunction<
        Int32 Function(IntPtr, Int32, Pointer<Void>, Uint32),
        int Function(int, int, Pointer<Void>, int)>('SetInformationJobObject');
    _openProcess = _kernel32.lookupFunction<
        IntPtr Function(Uint32, Int32, Uint32),
        int Function(int, int, int)>('OpenProcess');
    _assignProcessToJobObject = _kernel32.lookupFunction<
        Int32 Function(IntPtr, IntPtr),
        int Function(int, int)>('AssignProcessToJobObject');
    _closeHandle =
        _kernel32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'CloseHandle');
    _getLastError = _kernel32
        .lookupFunction<Uint32 Function(), int Function()>('GetLastError');
  }

  final DynamicLibrary _kernel32;
  late final int Function(Pointer<Void>, Pointer<Utf16>) _createJobObject;
  late final int Function(int, int, Pointer<Void>, int)
      _setInformationJobObject;
  late final int Function(int, int, int) _openProcess;
  late final int Function(int, int) _assignProcessToJobObject;
  late final int Function(int) _closeHandle;
  late final int Function() _getLastError;

  int createJobObject() {
    return _createJobObject(nullptr, nullptr.cast());
  }

  bool setInformationJobObject(
    int jobHandle,
    int informationClass,
    Pointer<Void> information,
    int informationLength,
  ) {
    return _setInformationJobObject(
          jobHandle,
          informationClass,
          information,
          informationLength,
        ) !=
        0;
  }

  int openProcess(
    int desiredAccess, {
    required bool inheritHandle,
    required int processId,
  }) {
    return _openProcess(desiredAccess, inheritHandle ? 1 : 0, processId);
  }

  bool assignProcessToJobObject(int jobHandle, int processHandle) {
    return _assignProcessToJobObject(jobHandle, processHandle) != 0;
  }

  bool closeHandle(int handle) {
    return _closeHandle(handle) != 0;
  }

  int lastError() => _getLastError();
}

final class _JobObjectExtendedLimitInformation extends Struct {
  external _JobObjectBasicLimitInformation basicLimitInformation;
  external _IoCounters ioInfo;

  @IntPtr()
  external int processMemoryLimit;

  @IntPtr()
  external int jobMemoryLimit;

  @IntPtr()
  external int peakProcessMemoryUsed;

  @IntPtr()
  external int peakJobMemoryUsed;
}

final class _JobObjectBasicLimitInformation extends Struct {
  @Int64()
  external int perProcessUserTimeLimit;

  @Int64()
  external int perJobUserTimeLimit;

  @Uint32()
  external int limitFlags;

  @IntPtr()
  external int minimumWorkingSetSize;

  @IntPtr()
  external int maximumWorkingSetSize;

  @Uint32()
  external int activeProcessLimit;

  @IntPtr()
  external int affinity;

  @Uint32()
  external int priorityClass;

  @Uint32()
  external int schedulingClass;
}

final class _IoCounters extends Struct {
  @Uint64()
  external int readOperationCount;

  @Uint64()
  external int writeOperationCount;

  @Uint64()
  external int otherOperationCount;

  @Uint64()
  external int readTransferCount;

  @Uint64()
  external int writeTransferCount;

  @Uint64()
  external int otherTransferCount;
}
