# EclipseXROM UEFI x64 PC device target

This repository contains the device configuration for bringing Android 17 (Android U) to UEFI-based x86_64 PCs such as the Lenovo Yoga 720. It layers on top of the Android-x86 manifest while providing a reproducible kernel workflow and image build pipeline (ISO and USB) tailored for EclipseXROM.

## Layout overview

| Path | Purpose |
| --- | --- |
| `AndroidProducts.mk`, `android_x86_64.mk`, `cm.mk` | Register the `cm_android_x86_64` product and lunch combos.
| `BoardConfig.mk` | Describes the x86_64 board, prebuilt kernel hook, and module packaging (including NVIDIA).
| `kern/linux-6.19.6/` | Extracted upstream kernel sources (place any newer tree here and point `KERNEL_TREE`).
| `kern/nvidia/` | Drop prebuilt NVIDIA modules here (they are picked up automatically).
| `kern/build_kernel.sh` | Helper script that builds the kernel from the extracted tree and refreshes the prebuilts consumed by the Android build.
| `prebuilts/kernel/` | Contains the resulting `bzImage` consumed as the board kernel.
| `prebuilts/modules/` | Aggregated kernel modules (stock + NVIDIA) copied into the vendor image.

## Sync prerequisites

```bash
repo init -u https://github.com/android-x86/manifest.git -b master
repo sync -c -j$(nproc)
```

Place this repository inside the synced tree under `device/eclipsex/uefix64pc` (or adjust the `inherit-product` path). The `cm_android_x86_64` target will then appear in `lunch` once you source `build/envsetup.sh`.

## Building the kernel from `kern/linux-6.19.6/`

1. Place the extracted kernel source tree inside `kern/linux-6.19.6/` (override via `KERNEL_TREE=/path/to/src`).
2. (Optional) Drop any NVIDIA `.ko` modules extracted from the proprietary driver into `kern/nvidia/`.
3. Run the helper script:
   ```bash
   cd device/eclipsex/uefix64pc
   # Customize DEFCONFIG/JOBS when necessary
   DEFCONFIG=android-x86_64_defconfig kern/build_kernel.sh
   ```

The script will:
- Build `bzImage` and in-tree modules with the selected defconfig from the existing source tree.
- Copy the kernel image to `prebuilts/kernel/bzImage` and refresh every module under `prebuilts/modules/`.
- Append any `.ko` files present in `kern/nvidia/` so NVIDIA graphics is available without rebuilding.

The Android build consumes those prebuilts via `TARGET_PREBUILT_KERNEL` and `BOARD_VENDOR_KERNEL_MODULES`, so rerun the script whenever you update the kernel archive or drivers.

## Building Android 17+ artifacts (ISO/USB)

```bash
source build/envsetup.sh
lunch cm_android_x86_64-userdebug
# Build the standard Android images
m -j$(nproc)
# Build bootable media
m iso_img   # produces out/target/product/android_x86_64/android_x86_64.iso
m usb_img   # produces out/target/product/android_x86_64/android_x86_64.usb.img
```

Flashing to USB can be done with `dd` or `usbcreator`. The ISO is hybrid and supports both BIOS/UEFI boot; the Lenovo Yoga 720 boots via UEFI by default.

## Display/touch status

- Display: relies on the Intel i915 stack in `linux-6.19.6`; make sure the kernel config enables `CONFIG_DRM_I915` and `CONFIG_DRM_KMS_HELPER` (already part of `android-x86_64_defconfig`).
- Touch: the Yoga 720 uses an I2C-HID panel which is supported upstream; confirm `CONFIG_I2C_HID_ACPI=y`.
- NVIDIA (optional eGPU/GTX models): place proprietary modules in `kern/nvidia` so they ship alongside the stock modules.

For deeper customisation (boot flags, firmware blobs, etc.), extend `BoardConfig.mk` or add overlays under `device/eclipsex/uefix64pc/overlay` as needed.
