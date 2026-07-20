# About the Project


## License and Usage
This library is licensed under the **Mozilla Public License 2.0
(`MPL-2.0`)**. It may be used, copied, modified, and redistributed for
commercial and non-commercial purposes.

The library may be used in proprietary games and other closed-source projects.
Only files containing MPL-covered code are subject to the MPL. Separate project
code, assets, and other files may remain proprietary.

See [`LICENSE`](LICENSE) for the complete license terms.


## Practical Compliance Guide
The Mozilla Public License 2.0 (`MPL-2.0`) uses file-level copyleft. Its
requirements apply to MPL-covered files and do not automatically extend to the
entire project in which those files are used.


### Internal Use
If the library is used or modified only within an organization and is not
distributed outside that organization, the MPL 2.0 does not require source
code disclosure.


### Distributing a Project
When distributing a game or another project that includes this library, the
distributor must:

* preserve all copyright and license notices in MPL-covered files;
* inform recipients that the covered source files are licensed under the
  MPL 2.0;
* include a copy of the MPL 2.0 or explain where it can be obtained;
* make the Source Code Form of every distributed MPL-covered file available
  to recipients, including any distributed modifications;
* distribute those source files and modifications under the MPL 2.0; and
* clearly explain where recipients can obtain the corresponding source code.

The source code must match the exact version distributed with the project. It
may be included as an archive or made available through a stable, documented
URL. Access may be limited to recipients and does not have to be available to
the general public.

If the MPL-covered files are already distributed in their editable `.gd`
Source Code Form, no additional source archive is required.

### Scope of File-Level Copyleft
Changes made inside an MPL-covered file remain covered by the MPL 2.0.

A new file that contains copied MPL-covered code is also covered by the
MPL 2.0, even if it originally had a different license.

A separate file that only calls the library's public API or subclasses one of
its types, without copying MPL-covered code, is not automatically covered.
Such files may remain proprietary.

### Godot Exports and PCK Files
MPL-covered GDScript files may be compiled, encrypted, or included in a PCK.
If their editable Source Code Form is not included in the exported project, it
must be provided separately or made available through the documented source
link.

The PCK and the library do not have to be replaceable. The MPL 2.0 does not
require object files, relinking support, or a mechanism for loading modified
versions of the library.


### What Is Not Required
The distributor is not required to:

* disclose independent proprietary game source code;
* disclose game assets or other independent project files;
* make the PCK or library replaceable;
* provide object files or support relinking;
* publish the source code on GitHub or another public platform;
* provide support for modified versions of the library; or
* submit modifications upstream or send them to the original developer.


### Source File Notice
Each MPL-covered source file should contain the following notice. Replace the
placeholders with the correct information and preserve existing notices from
other contributors.

```gdscript
# SPDX-FileCopyrightText: [year] [copyright holder]
# SPDX-License-Identifier: MPL-2.0
```

### Example Distribution Layout
The following layout illustrates one possible Godot distribution:

```text
MyGame/
├── MyGame.exe
├── MyGame.pck
├── licenses/
│   ├── THIRD_PARTY_NOTICES.txt
│   └── MPL-2.0.txt
└── open_source/
    └── example_library-1.4.2-source.zip
```

Alternatively, `THIRD_PARTY_NOTICES.txt` may link to the exact library release
used by the game, provided that the corresponding source remains available to
the recipients.

If one or more MPL-covered `.gd` files have been modified, the source archive
must contain the exact versions used by the game, including those
modifications. Independent proprietary game code does not need to be included.


### Third-Party Notice Example
The following text may be included in `THIRD_PARTY_NOTICES.txt`:

```text
This product includes [Library Name] [version].

Copyright (c) [year] [copyright holder]

[Library Name] is licensed under the Mozilla Public License 2.0
(MPL-2.0).

The Source Code Form of all MPL-covered files, including the modifications
used in this product, is available at:

https://example.com/opensource/mygame/example-library-1.4.2-source.zip

A copy of the Mozilla Public License 2.0 is included in the licenses
directory.
```


### EULA Compatibility Example
A proprietary EULA must not restrict the rights granted for MPL-covered
source files. The following exception may be included:

```text
Notwithstanding any other provision of this EULA, the open-source components
listed in THIRD_PARTY_NOTICES.txt are governed by their respective licenses.

If this EULA conflicts with an applicable open-source license, that license
governs the relevant component. Nothing in this EULA restricts rights granted
under the Mozilla Public License 2.0 with respect to MPL-covered source code.
```

This guide is only a practical summary. If it conflicts with the Mozilla
Public License 2.0, the official license text takes precedence.


## Contributing
Contributions and upstream submissions of improvements are welcome.

By submitting a contribution to this repository, you agree to license it under
the Mozilla Public License 2.0 (`MPL-2.0`).


## Installation
Copy the `aggl/` directory into the `addons/` directory of
your Godot project:

```text
res://addons/aggl/
```

If `aggl/` contains a `plugin.cfg`, enable the plugin under **Project > Project Settings > Plugins**.
