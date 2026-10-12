# Third-party software and asset notices

First-party game code, schemas, and created assets are licensed under MIT. This file records external dependencies and assets separately; their licenses remain their own and must be reviewed before redistribution.

## First-party assets

| Asset | Creator and provenance | License |
|---|---|---|
| `icon.svg` | Frontier Systems project; original geometric artwork created for this repository | MIT |
| `docs/community/indiedb/cards/*.svg`, `*.png` | Valithor / Frontier Systems project; hand-authored vector diagrams and raster renders, no imported source artwork or gameplay captures; PNGs rendered with Microsoft Edge | MIT |

## Planned dependencies

| Dependency | Planned use | License and provenance | Integration state |
|---|---|---|---|
| Godot Engine 4.7 | Game runtime and editor | MIT; https://godotengine.org/license/ | Project configured for 4.7. |
| GodotSteam GDExtension | Steamworks API and Steam multiplayer adapter | MIT project; https://codeberg.org/godotsteam/godotsteam | `addons/godotsteam/`, Asset Library release 4.23.1, source commit `87e9456ed0922d861d352cda823ee1bde682c987`, Steamworks SDK 1.65. The release targets Godot 4.4+ and includes platform binaries. Valve's Steamworks SDK terms remain separate. |
| Monolog 3.12.1 | Shared DiscordPHP game-event logging adapter | MIT; https://github.com/Seldaek/monolog | Runtime dependency pinned in services/control-plane/composer.lock; vendor license retained by Composer/PHAR packaging. |
| ReactPHP components | PHP event loop, promises, HTTP, sockets, and cache | MIT components; https://reactphp.org/ | Installed in `services/control-plane/composer.lock`. |
| DiscordPHP | Discord Social SDK integration and application-side Discord services | MIT; https://github.com/discord-php/DiscordPHP | Existing project maintained by the project owner; integration is a separate adapter package. |
| TwitchPHP | Preferred future OAuth, Helix and EventSub provider | MIT; https://github.com/Valgorithms/TwitchPHP | Reviewed local source revision `26a6c39202c951030bdb436d04af9e064a9b4e3f`; framework requires PHP 8.4. Not bundled/installed into Frontier yet. |
| TwitchPHP-Http | Preferred asynchronous Twitch HTTP/OAuth dependency | MIT; https://github.com/Valgorithms/TwitchPHP-Http | Reviewed local revision `c1cb8a7e176535f7e103317ee5c88476cf373f99`; source/retry boundary documented. Not bundled/installed into Frontier yet. |
| PHP-CS-Fixer | PHP formatting | MIT | Composer dev dependency; not shipped as a runtime dependency. |
| PHPUnit | Unit-test runner | BSD-3-Clause | Composer dev dependency; not shipped as a runtime dependency. |
| PHPDocumentor shim | API documentation | MIT | Composer dev dependency; not shipped as a runtime dependency. |
| PHPacker | Optional standalone binary packaging | MIT | Composer dev dependency; not shipped as a runtime dependency. |
| GitHub Actions checkout, setup-php, and setup-godot actions | CI runner setup | MIT | Used by `.github/workflows/ci.yml`; action versions are updated by Dependabot. |

## Asset intake requirements

The optional `packages/twitch` adapter is first-party MIT code and reuses ReactPHP/PSR software dependencies. It bundles no Twitch SDK, Extension Helper script, logos or other creative assets. Access to Twitch APIs/services and any later Extension deployment is governed separately by Twitch's platform terms.

Before adding an external art, audio, font, model, texture, or code asset, record its title, author, source URL, exact license/version, required attribution, modifications, and redistribution terms here. Prefer first-party material that the project can license under MIT and external creative assets under CC0. External software dependencies require an individually approved permissive license and retained notices. Do not assume that "free" means commercially redistributable, and do not add differently licensed creative assets without an explicit project-policy change.

## Procedural habitat visual details

The resource clusters/prism, workbench supports/surfaces, tray rims/pedestals and terrain outlines in src/presentation/habitat/habitat_visual_details.gd are independently authored first-party MIT GDScript/Godot primitive geometry and materials. Creation tools: text editing and ordinary Godot 4.7.2 engine rendering. No imported source artwork, new fonts, third-party creative assets, AI image generation or generative intermediate assets are used. Internal graphical captures are ignored local diagnostics and are not shipped or uploaded.

## Engineering object recognition geometry

`src/presentation/production/engineering_object_details.gd` independently authors extractor gantry/auger collars, refinery vessels/pipe bridge, and framed recessed spatial wall panels. Author: Frontier Systems project (Codex-assisted original procedural geometry); license: MIT. Tools: text editing, Godot BoxMesh/CylinderMesh/StandardMaterial3D and ordinary Godot 4.7.2 rendering. No source artwork, imported models/textures/fonts, third-party creative assets or generative image intermediates. Internal native captures remain ignored local diagnostics.

## Observed machinery activity geometry

`src/presentation/production/machinery_activity_parts.gd` supplies original extractor drive vanes, refinery pump rotor and activity indicator geometry. Author: Frontier Systems project (Codex-assisted original procedural geometry); license: MIT. Creation tools: text editing, Godot BoxMesh/StandardMaterial3D and bounded ordinary transforms, native Godot 4.7.2 rendering. No source artwork, imported creative assets or generative imagery/intermediates. These cosmetic nodes have no collision or persistence. Internal native still captures remain ignored local diagnostics; no videos or uploads.

## Portable tool and resource item geometry

`src/presentation/inventory/inventory_item_silhouettes.gd` independently authors hooked crowbars, extractor body/grip/nozzle and cylindrical resource canisters with base/shoulder/neck. Author: Frontier Systems project (Codex-assisted original procedural geometry); license: MIT. Creation tools: text editing, Godot BoxMesh/CylinderMesh/StandardMaterial3D and ordinary Godot 4.7.2 rendering. No source artwork, imported models/textures/fonts, third-party creative dependencies or generative image intermediates. Shape denotes catalog role only, without claims about contents, capabilities or part condition. Internal native stills remain ignored local diagnostics.

The same original MIT helper also authors the backpack rigid body, rounded shoulders, front/side pockets, rear straps and grab handle using BoxMesh/CylinderMesh. Author: Frontier Systems project (Codex-assisted original procedural geometry); creation tools: text editing and ordinary Godot rendering. No source artwork, generative intermediates or third-party creative dependencies. These parts denote the backpack catalog role only.
