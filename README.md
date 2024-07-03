# scudo-zig

Scudo Allocator for Zig

## Requires

- [Zig](https://ziglang.org/download) v0.13.0 or master


## How to use

```bash
# Create a project
$ mkdir project_name
$ cd project_name
$ zig init

# get zig-scudo (add on zon file - overwrited)
zig fetch --save=scudo git+https://github.com/kassane/zig-scudo
```

In `build.zig`, add:
```zig
// pkg name (same in zon file)
const scudo_dep = b.dependency("scudo",.{.target = target, .optimize = optimize });
const scudo_module = scudo_dep.module("scudoAllocator"); // get lib + zig bindings

// my project (executable)
exe.root_module.addImport("scudoAllocator", scudo_module);
```

## References

- [LLVM-Doc: Scudo Allocator](https://llvm.org/docs/ScudoHardenedAllocator.html)
- [SCUDO Hardened Allocator — Unofficial Internals](https://www.l3harris.com/newsroom/editorial/2023/10/scudo-hardened-allocator-unofficial-internals-documentation) authored by [Rodrigo Rubira](https://github.com/rrbranco)
- [High level overview of Scudo](https://expertmiami.blogspot.com/2019/05/high-level-overview-of-scudo.html) by Kostya
- [What is the Scudo hardened allocator?](https://expertmiami.blogspot.com/2019/05/what-is-scudo-hardened-allocator_10.html) by Kostya
- [google/rust-scudo](https://github.com/google/rust-scudo)