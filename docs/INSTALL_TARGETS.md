# NeurX Target Installation Guide

This document describes how to install and deploy NeurX as an AI operating system across desktop, mobile, tablet, robot, automotive, and embedded targets.

## Installation Model

NeurX should be deployed as layered packages instead of a single universal bundle.

- `neurx-core`: kernel, runtime, memory, storage, IPC, security
- `neurx-ai`: planner, reasoning, reflection, context, perception, world model
- `neurx-service`: local or remote backend services, model gateway, task service
- `neurx-target-*`: target-specific UI, drivers, packaging, and startup configuration

## Desktop

Targets:
- Windows
- Linux
- macOS

Primary entrypoints:
- [Makefile](/c:/Users/shuwen/neurx/Makefile:1)
- [app/README.md](/c:/Users/shuwen/neurx/app/README.md:1)
- [targets/desktop/target.s](/c:/Users/shuwen/neurx/targets/desktop/target.s:1)

Recommended install flow:
1. Install the S compiler and Qt runtime/toolchain.
2. Build the NeurX core runtime with `make neurx`.
3. Launch the desktop shell with `make windows`, `make linux`, or `make macos`.
4. Point the app at a local model or remote backend through environment variables.

Desktop should provide:
- local filesystem access
- terminal and developer tools
- local or remote model selection
- full session, artifact, and workspace management

## Mobile

Targets:
- Android
- iPhone

Primary entrypoints:
- [app/mobile/README.md](/c:/Users/shuwen/neurx/app/mobile/README.md:1)
- [app/mobile/scripts/build_android.sh](/c:/Users/shuwen/neurx/app/mobile/scripts/build_android.sh:1)
- [app/mobile/scripts/build_ios.sh](/c:/Users/shuwen/neurx/app/mobile/scripts/build_ios.sh:1)
- [targets/mobile/target.s](/c:/Users/shuwen/neurx/targets/mobile/target.s:1)

Recommended install flow:
1. Build the mobile shell package.
2. Deploy the client to the device.
3. Connect the client to a local NeurX service or remote NeurX backend.
4. Enable mobile-safe drivers only, such as camera, QR, voice, and file pickers.

Mobile should provide:
- lightweight agent client
- short-lived local context and session cache
- remote backend connection by default
- optional small local model support

## Tablet

Primary entrypoint:
- [targets/tablet/target.s](/c:/Users/shuwen/neurx/targets/tablet/target.s:1)

Tablet should be deployed as a larger-screen mobile target with:
- split-pane UI
- keyboard and stylus support
- document and task dashboard views
- shared backend and package base with mobile

## Robot

Primary entrypoint:
- [targets/robot/target.s](/c:/Users/shuwen/neurx/targets/robot/target.s:1)

Recommended install flow:
1. Install `neurx-core` on the robot controller or edge box.
2. Install `neurx-ai` with a compact local policy/model stack.
3. Add robot-specific drivers and sensor adapters.
4. Start local services for perception, planning, control, and telemetry.

Robot should provide:
- low-latency IPC
- sensor input handling
- local world model
- action planning and safety stop paths
- offline-capable operation

## Automotive

Primary entrypoint:
- [targets/auto/target.s](/c:/Users/shuwen/neurx/targets/auto/target.s:1)

Recommended install flow:
1. Install `neurx-core` inside the in-vehicle compute environment.
2. Install `neurx-target-auto` with vehicle UI, vehicle policy, and bus adapters.
3. Connect to in-car services through secure IPC and approved drivers.
4. Enable rollback-safe OTA updates and policy gates.

Automotive should provide:
- cockpit assistant UI
- vehicle-safe task isolation
- CAN/LIN/GPS/camera integration through drivers
- strict security and safety approval boundaries

## Embedded

Primary entrypoint:
- [targets/embedded/target.s](/c:/Users/shuwen/neurx/targets/embedded/target.s:1)

Recommended install flow:
1. Install a reduced `neurx-core`.
2. Deploy only the required AI modules for the target workload.
3. Use compact models, quantized weights, and bounded memory pools.
4. Run a small service set with watchdog and restart policy.

Embedded should provide:
- low-memory runtime
- bounded local storage
- compact models
- resilient offline execution

## Package Layout

Suggested package mapping:

- `packages/neurx-core/`: runtime, kernel, storage, IPC, security
- `packages/neurx-ai/`: planner, reasoning, reflection, context, world model
- `packages/neurx-service/`: backend serving, task orchestration, service wrappers
- `packages/neurx-target-desktop/`: desktop UI and desktop startup integration
- `packages/neurx-target-mobile/`: Android/iOS packaging and mobile startup integration
- `packages/neurx-target-tablet/`: tablet shell and large-screen layout assets
- `packages/neurx-target-robot/`: robotics drivers, control services, and deployment config
- `packages/neurx-target-auto/`: automotive drivers, vehicle services, and policy config
- `packages/neurx-target-embedded/`: minimal runtime profile and embedded deployment config

## Deployment Directories

Suggested deployment tree:

- `deploy/desktop/`: desktop installers and launch scripts
- `deploy/mobile/`: mobile packaging and deployment helpers
- `deploy/tablet/`: tablet packaging and layout configuration
- `deploy/robot/`: robotics deployment bundles
- `deploy/auto/`: automotive deployment bundles
- `deploy/embedded/`: embedded provisioning and image assembly helpers
