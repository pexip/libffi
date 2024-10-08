ffi_c_sources = [
  'prep_cif.c',
  'types.c',
  'raw_api.c',
  'java_raw_api.c',
  'closures.c',
]

ffi_asm_sources = []

if get_option('ffi-debug')
  ffi_c_sources += ['debug.c']
endif

# This if/else ladder is based on the configure.host file
TARGET = ''
if host_cpu_family.startswith('x86')
  arch_subdir = 'x86'
  if host_system == 'windows'
    if size_t == 4
      TARGET = 'X86_WIN32'
      if cc.get_id() == 'msvc'
        c_sources = ['ffiold-msvc.c']
        asm_sources = ['win32_msvc.S']
      else
        c_sources = ['ffi.c']
        asm_sources = ['sysv.S']
      endif
    else
      TARGET = 'X86_WIN64'
      c_sources = ['ffiw64.c']
      if cc.get_id() == 'msvc'
        asm_sources = ['win64_intel.S']
      else
        asm_sources = ['win64.S']
      endif
    endif
  elif ['darwin', 'ios', 'linux', 'android'].contains(host_system)
    if size_t == 4
      if ['darwin', 'ios'].contains(host_system)
        TARGET = 'X86_DARWIN'
      else
        TARGET = 'X86'
      # FIXME: TARGET_X32 support
      endif
      c_sources = ['ffi.c']
      asm_sources = ['sysv.S']
    else
      TARGET = 'X86_64'
      c_sources = ['ffi64.c', 'ffiw64.c']
      asm_sources = ['unix64.S', 'win64.S']
    endif
  endif
elif host_cpu_family == 'aarch64'
  arch_subdir = 'aarch64'
  TARGET = 'AARCH64'
  c_sources = ['ffi.c']
  asm_sources = ['sysv.S']
elif host_cpu_family == 'arm'
  arch_subdir = 'arm'
  TARGET = 'ARM'
  c_sources = ['ffi.c']
  asm_sources = ['sysv.S']
endif

if TARGET == ''
  error('Unsupported pair: system "@0@", cpu family "@1@"'.format(host_system, host_cpu_family))
endif

# Translate source files to source paths
foreach c : c_sources
  ffi_c_sources += arch_subdir + '/' + c
endforeach
foreach asm : asm_sources
  ffi_asm_sources += arch_subdir + '/' + asm
endforeach

# Used in ffi.h.in to generate ffi-$arch.h
ffi_conf.set('TARGET', TARGET)
ffi_conf.set('VERSION', meson.project_version())

if cc.get_id() == 'msvc'
  # GCC and Clang accept assembly files directly, but MSVC's cl.exe does not.
  # You need to manually pass the files through the pre-processor first and
  # then through the assembler, and then link the objects into the target.
  # FIXME: Add native support in Meson for this.
  cl = find_program('cl')
  ml = find_program('ml', 'ml64')
  ffi_asm_objs = []
  foreach asm_source : ffi_asm_sources
    incflags = ['/I' + join_paths(meson.current_source_dir(), '..'),
                '/I' + join_paths(meson.current_build_dir(), '..'),
                '/I' + join_paths(meson.current_source_dir(), '..', 'include'),
                '/I' + join_paths(meson.current_build_dir(), '..', 'include')]
    preproc_name = asm_source.underscorify() + '.i'
    obj_name = asm_source.underscorify() + '.obj'
    preproc = custom_target(preproc_name,
        input : asm_source,
        output : preproc_name,
        command : [cl, '/nologo', '/EP', '/P', '/Fi@OUTPUT@',
                   '/DTARGET=' + TARGET, '/DFFI_BUILDING',
                   '@INPUT@'] + incflags)
    ffi_asm_objs += custom_target(obj_name,
        input : preproc,
        output : obj_name,
        command : [ml, '/Fo', '@OUTPUT@', '/c', '@INPUT@'])
  endforeach
  ffi_asm_sources = ffi_asm_objs
endif

ffi_lib = library('ffi', ffi_c_sources, ffi_asm_sources,
  c_args : '-DTARGET=' + TARGET,
  include_directories : ffiinc,
  # Taken from the libtool-version file
  # current - age . age . revision
  version : '7.1.0',
  # current - age
  soversion : '7',
  # current + 1
  darwin_versions : '9',
  install : true)

ffi_dep = declare_dependency(link_with : ffi_lib,
  compile_args : static_build ? [ ffi_static_build ] : [],
  include_directories : ffiinc)
