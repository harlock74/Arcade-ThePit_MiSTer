# Third-party notices

This notice records component provenance and distribution obligations; it is not a blanket licence or legal-clearance statement. Original source headers remain authoritative. `NOTICE.md` records component attribution and terms; original source headers retain file-level notices.

## MiSTer framework and video/audio helpers

`sys/` derives from the pinned MiSTer Template comparison at `3ea1134cf05d62c2b1db30362277a823d739ced2`. That pin is the verified comparison/import record for the initial The Pit framework, not proof of every later game's exact import event. Headers credit Till Harbaum, Alexey Melnikov/Sorgelig, Ludvig Strigeus, Mike Simone, bellwood420, TEMLIB and the other holders named in the distributed source and retained source headers. Terms are mixed: explicit GPL-2.0-or-later and GPL-3.0-or-later headers, LGPL-3.0-or-later components, TEMLIB's permissive notice in `ascal.vhd`, and headerless helpers treated under the pinned Template's GPLv2 package context where documented. `LICENSES/GPL-2.0.txt`, `GPL-3.0.txt`, `LGPL-3.0.txt`, and `TEMLIB.txt` preserve the applicable reference texts/notices. Specific file headers override generic summaries.

Known retained local framework changes are: removal of dangling optional `.cmp` metadata references in `sys/pll_hdmi.qip` and `sys/pll_audio.qip`; correction of the switch-port Tcl expression in `sys/sys_top.sdc`; module-scope PS2 declarations in `sys/hps_io.sv`; procedural-variable declaration fixes in `sys/ddr_svc.sv` and `sys/f2sdram_safe_terminator.sv`; and explicit zero for the reserved fifth `ascal.mode` bit in `sys/sys_top.v`. The scaler-mode change replaces an implicit width extension with `{1'b0,~lowlat,LFB_EN ? LFB_FLT : |scaler_flt,2'b00}`, retaining the four existing control bits. These are local build/functional configuration differences from upstream, not a framework update.

## T80 and JT49

The T80 sources under `rtl/vendor/T80/` retain Daniel Wallner's copyright, source/synthesized-form redistribution conditions and disclaimer, along with MikeJ, Sorgelig and other revision credits present in each file. Because the RBF is a synthesized distribution, the required common notice is reproduced in `LICENSES/T80-source-synthesized.txt`; variant source headers remain authoritative.

JT49 sources under `rtl/vendor/jt49/` credit Jose Tejada Gomez and contributors and are GPL-3.0-or-later. Their full GPLv3 text is retained both with JT49 and in `LICENSES/GPL-3.0.txt`. `rtl/thepit_tone.sv` is the documented local reduced-function JT49 tone derivative; the seven vendored JT49 HDL files remain unchanged. See `rtl/vendor/jt49/VENDORING.md`.

## Intel/Altera inputs

The active PLL and reconfiguration inputs under `rtl/pll*` and `sys/pll*` retain Intel/Altera proprietary headers. The established Quartus Prime 17.0 Web Download Agreement assessment supports modification and redistribution of the identified ordinary IP components under §2.5 only for programming Altera devices, with required proprietary notices preserved. This project targets Cyclone V `5CSEBA6U23I7`.

The documented §20 question remains: the agreement conditionally restricts combinations that subject Intel Licensed Software to GPL/LGPL obligations, and whether this exact configured source/RBF does so remains an interpretation issue. Published MiSTer practice supplies context, not an additional permission or blanket exception. The private agreement is not included. No guaranteed legal clearance is claimed.

## Project lineage and excluded reference material

Round-Up and Super Mouse were developed from The Pit and deliberately reuse named The Pit-derived modules while adding game-specific maps, graphics, controls, loaders and persistence. They have separate compiled binaries and validation records. MAME source, schematics and manuals were development references only and are not distributed. Game ROMs, personal NVM files, private evidence, compiler databases and correspondence are excluded.
